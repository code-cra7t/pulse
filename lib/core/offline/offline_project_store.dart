import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/projects/models/project.dart';
import 'offline_database_factory.dart';
import 'pending_project_mutation.dart';

typedef OpenProjectsOfflineDatabase = Future<Database> Function();

class OfflineProjectStore {
  OfflineProjectStore({OpenProjectsOfflineDatabase? openDatabase})
    : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenProjectsOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, dynamic>> _projectsStore =
      stringMapStoreFactory.store('projects');
  final StoreRef<String, Map<String, dynamic>> _mutationsStore =
      stringMapStoreFactory.store('pending_project_mutations');
  final Map<String, StreamController<List<Project>>> _controllers = {};

  Future<Database>? _databaseFuture;

  Future<Database> get _database {
    return _databaseFuture ??= _openDatabase();
  }

  String _projectKey(String userId, String projectId) => '$userId::$projectId';

  Stream<List<Project>> watchProjects(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<List<Project>>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );

    unawaited(_emit(userId));
    return controller.stream;
  }

  Future<Project?> readProject(String userId, String projectId) async {
    final database = await _database;
    final value = await _projectsStore
        .record(_projectKey(userId, projectId))
        .get(database);
    if (value == null) {
      return null;
    }
    return Project.fromLocalMap(value);
  }

  Future<List<Project>> readProjects(String userId) async {
    final database = await _database;
    final snapshots = await _projectsStore.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [
          SortOrder('status'),
          SortOrder('deadlineMs'),
          SortOrder('updatedAtMs', false),
          SortOrder('createdAtMs', false),
        ],
      ),
    );

    final projects = snapshots
        .map((snapshot) => Project.fromLocalMap(snapshot.value))
        .toList(growable: false);
    return _sortedProjects(projects);
  }

  Future<void> stageUpsert(
    Project project,
    PendingProjectMutation mutation,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _projectsStore
          .record(_projectKey(project.userId, project.id))
          .put(transaction, project.toLocalMap());
      await _replacePendingMutation(transaction, mutation);
    });
    await _emit(project.userId);
  }

  Future<void> stageDelete(
    String userId,
    String projectId,
    PendingProjectMutation mutation,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _projectsStore
          .record(_projectKey(userId, projectId))
          .delete(transaction);
      await _replacePendingMutation(transaction, mutation);
    });
    await _emit(userId);
  }

  Future<void> mergeRemoteProjects(
    String userId,
    List<Project> remoteProjects,
  ) async {
    final database = await _database;

    await database.transaction((transaction) async {
      final pendingSnapshots = await _mutationsStore.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      final protectedProjectIds = {
        for (final snapshot in pendingSnapshots)
          snapshot.value['projectId'] as String? ?? '',
      };
      final localSnapshots = await _projectsStore.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );

      for (final snapshot in localSnapshots) {
        final projectId = snapshot.value['id'] as String? ?? '';
        if (!protectedProjectIds.contains(projectId)) {
          await _projectsStore.record(snapshot.key).delete(transaction);
        }
      }

      for (final project in remoteProjects) {
        if (protectedProjectIds.contains(project.id)) {
          continue;
        }
        await _projectsStore
            .record(_projectKey(userId, project.id))
            .put(transaction, project.toLocalMap());
      }
    });

    await _emit(userId);
  }

  Future<List<PendingProjectMutation>> pendingMutations(String userId) async {
    final database = await _database;
    final snapshots = await _mutationsStore.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('createdAtMs')],
      ),
    );

    return snapshots
        .map((snapshot) => PendingProjectMutation.fromLocalMap(snapshot.value))
        .toList(growable: false);
  }

  Future<void> removeMutation(String mutationId) async {
    final database = await _database;
    await _mutationsStore.record(mutationId).delete(database);
  }

  Future<void> clearUser(String userId) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _projectsStore.delete(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      await _mutationsStore.delete(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
    });
    await _emit(userId);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();

    final databaseFuture = _databaseFuture;
    if (databaseFuture != null) {
      final database = await databaseFuture;
      await database.close();
    }
  }

  Future<void> _replacePendingMutation(
    DatabaseClient database,
    PendingProjectMutation mutation,
  ) async {
    final existing = await _mutationsStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('userId', mutation.userId),
          Filter.equals('projectId', mutation.projectId),
        ]),
      ),
    );

    for (final snapshot in existing) {
      await _mutationsStore.record(snapshot.key).delete(database);
    }
    await _mutationsStore
        .record(mutation.id)
        .put(database, mutation.toLocalMap());
  }

  Future<void> _emit(String userId) async {
    final controller = _controllers[userId];
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(await readProjects(userId));
  }
}

List<Project> _sortedProjects(Iterable<Project> projects) {
  final sorted = projects.toList(growable: false);
  sorted.sort((a, b) {
    final statusCompare = _statusOrder(
      a.status,
    ).compareTo(_statusOrder(b.status));
    if (statusCompare != 0) {
      return statusCompare;
    }

    final aDeadline = a.deadline;
    final bDeadline = b.deadline;
    if (aDeadline != null && bDeadline != null) {
      final deadlineCompare = aDeadline.compareTo(bDeadline);
      if (deadlineCompare != 0) {
        return deadlineCompare;
      }
    } else if (aDeadline != null) {
      return -1;
    } else if (bDeadline != null) {
      return 1;
    }

    final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
    if (updatedCompare != 0) {
      return updatedCompare;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

int _statusOrder(ProjectStatus status) {
  return switch (status) {
    ProjectStatus.active => 0,
    ProjectStatus.paused => 1,
    ProjectStatus.completed => 2,
    ProjectStatus.archived => 3,
  };
}
