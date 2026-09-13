import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/offline/offline_project_store.dart';
import '../../../core/offline/pending_project_mutation.dart';
import '../models/project.dart';
import 'projects_repository.dart';

class OfflineFirstProjectsRepository implements ProjectsRepository {
  OfflineFirstProjectsRepository(this._firestore, this._offlineStore);

  final FirebaseFirestore _firestore;
  final OfflineProjectStore _offlineStore;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _remoteSubscriptions = {};
  final Set<String> _syncingUsers = {};
  final Set<String> _syncRequestedUsers = {};

  CollectionReference<Map<String, dynamic>> get _projectsCollection {
    return _firestore.collection('projects');
  }

  @override
  Stream<List<Project>> watchProjects(String userId) {
    _stopWatchingOtherUsers(userId);
    _startRemoteListener(userId);
    unawaited(synchronize(userId));
    return _offlineStore.watchProjects(userId);
  }

  @override
  Future<Project?> readProject(String userId, String projectId) {
    return _offlineStore.readProject(userId, projectId);
  }

  @override
  Future<Project> createProject({
    required String userId,
    required String name,
    String description = '',
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Project name cannot be empty.');
    }

    final now = DateTime.now();
    final project = Project(
      id: _projectsCollection.doc().id,
      userId: userId,
      name: normalizedName,
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _offlineStore.stageUpsert(project, _upsertMutation(project));
    unawaited(synchronize(userId));
    return project;
  }

  @override
  Future<void> updateProject(Project project) async {
    final normalizedName = project.name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        project.name,
        'project.name',
        'Project name cannot be empty.',
      );
    }
    final targetMinutesPerWeek = project.targetMinutesPerWeek;
    if (targetMinutesPerWeek != null && targetMinutesPerWeek < 0) {
      throw ArgumentError.value(
        targetMinutesPerWeek,
        'project.targetMinutesPerWeek',
        'Weekly target cannot be negative.',
      );
    }

    final updated = project.copyWith(
      name: normalizedName,
      description: project.description.trim(),
      updatedAt: DateTime.now(),
    );
    await _offlineStore.stageUpsert(updated, _upsertMutation(updated));
    unawaited(synchronize(updated.userId));
  }

  @override
  Future<void> deleteProject(String userId, String projectId) async {
    final mutation = PendingProjectMutation(
      id: _mutationId(projectId),
      userId: userId,
      projectId: projectId,
      type: PendingProjectMutationType.delete,
      payload: null,
      createdAt: DateTime.now(),
    );

    await _offlineStore.stageDelete(userId, projectId, mutation);
    unawaited(synchronize(userId));
  }

  Future<void> synchronize(String userId) async {
    _syncRequestedUsers.add(userId);
    if (!_syncingUsers.add(userId)) {
      return;
    }

    try {
      while (_syncRequestedUsers.remove(userId)) {
        while (true) {
          final pending = await _offlineStore.pendingMutations(userId);
          if (pending.isEmpty) {
            break;
          }

          var allPushed = true;
          for (final mutation in pending) {
            if (!await _pushMutation(mutation)) {
              allPushed = false;
              break;
            }
          }
          if (!allPushed) {
            return;
          }
        }

        try {
          final snapshot = await _projectsCollection
              .where('userId', isEqualTo: userId)
              .get(const GetOptions(source: Source.server));
          await _offlineStore.mergeRemoteProjects(
            userId,
            snapshot.docs.map(Project.fromFirestore).toList(growable: false),
          );
        } on FirebaseException catch (error, stackTrace) {
          debugPrint(
            '[ProjectsRepository] event=remote_pull_deferred userId=$userId '
            'error=$error\n$stackTrace',
          );
        }
      }
    } finally {
      _syncingUsers.remove(userId);
    }
  }

  Future<void> dispose() async {
    final subscriptions = _remoteSubscriptions.values.toList(growable: false);
    _remoteSubscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  void _startRemoteListener(String userId) {
    if (_remoteSubscriptions.containsKey(userId)) {
      return;
    }

    _remoteSubscriptions[userId] = _projectsCollection
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (snapshot.metadata.isFromCache) {
              return;
            }
            unawaited(
              _offlineStore.mergeRemoteProjects(
                userId,
                snapshot.docs
                    .map(Project.fromFirestore)
                    .toList(growable: false),
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              '[ProjectsRepository] event=remote_listener_deferred '
              'userId=$userId error=$error\n$stackTrace',
            );
          },
        );
  }

  void _stopWatchingOtherUsers(String activeUserId) {
    final otherUserIds = _remoteSubscriptions.keys
        .where((userId) => userId != activeUserId)
        .toList(growable: false);
    for (final userId in otherUserIds) {
      final subscription = _remoteSubscriptions.remove(userId);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
    }
  }

  Future<bool> _pushMutation(PendingProjectMutation mutation) async {
    try {
      final reference = _projectsCollection.doc(mutation.projectId);
      if (mutation.type == PendingProjectMutationType.delete) {
        await reference.delete();
      } else {
        final payload = mutation.payload;
        if (payload == null) {
          throw StateError('An upsert mutation requires a project payload.');
        }
        await reference.set(
          Project.fromLocalMap(payload).toMap(),
          SetOptions(merge: true),
        );
      }
      await _offlineStore.removeMutation(mutation.id);
      return true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[ProjectsRepository] event=mutation_queued '
        'projectId=${mutation.projectId} type=${mutation.type.name} '
        'error=$error\n$stackTrace',
      );
      return false;
    }
  }

  PendingProjectMutation _upsertMutation(Project project) {
    return PendingProjectMutation(
      id: _mutationId(project.id),
      userId: project.userId,
      projectId: project.id,
      type: PendingProjectMutationType.upsert,
      payload: project.toLocalMap(),
      createdAt: DateTime.now(),
    );
  }

  String _mutationId(String projectId) {
    return '${DateTime.now().microsecondsSinceEpoch}-$projectId';
  }
}
