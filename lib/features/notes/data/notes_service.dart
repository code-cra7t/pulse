import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/offline/offline_note_store.dart';
import '../../../core/offline/pending_note_mutation.dart';
import '../models/note.dart';
import '../utils/tag_parser.dart';
import '../utils/task_parser.dart';

class NotesService {
  NotesService(this._firestore, this._storage, this._offlineStore);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final OfflineNoteStore _offlineStore;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _remoteSubscriptions = {};
  final Set<String> _syncingUsers = {};
  final Set<String> _syncRequestedUsers = {};

  CollectionReference<Map<String, dynamic>> get _notesCollection {
    return _firestore.collection('notes');
  }

  Stream<List<Note>> watchNotes(String userId) {
    _stopWatchingOtherUsers(userId);
    _startRemoteListener(userId);
    unawaited(synchronize(userId));
    return _offlineStore.watchNotes(userId);
  }

  Future<Note> createNote({
    required String userId,
    String? title,
    bool isPinned = false,
    required String content,
    required int color,
    List<String> tags = const [],
    List<String> images = const [],
  }) async {
    final normalizedContent = TaskParser.normalizeTaskContent(content);
    final storedTags = _mergedTags(tags, normalizedContent);
    final now = DateTime.now();
    final note = Note(
      id: _notesCollection.doc().id,
      userId: userId,
      title: title,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
      tags: storedTags,
      content: normalizedContent,
      color: color,
      images: images,
    );
    final mutation = _upsertMutation(note);

    await _offlineStore.stageUpsert(note, mutation);
    unawaited(synchronize(userId));
    return note;
  }

  Future<void> updateNote(Note note) async {
    final normalizedContent = TaskParser.normalizeTaskContent(note.content);
    final updatedNote = note.copyWith(
      content: normalizedContent,
      tags: _mergedTags(note.tags, normalizedContent),
      updatedAt: DateTime.now(),
    );
    final mutation = _upsertMutation(updatedNote);

    await _offlineStore.stageUpsert(updatedNote, mutation);
    unawaited(synchronize(updatedNote.userId));
  }

  Future<void> deleteNote(String noteId, {required String userId}) async {
    final mutation = PendingNoteMutation(
      id: _mutationId(noteId),
      userId: userId,
      noteId: noteId,
      type: PendingNoteMutationType.delete,
      payload: null,
      createdAt: DateTime.now(),
    );

    await _offlineStore.stageDelete(userId, noteId, mutation);
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
          final snapshot = await _notesCollection
              .where('userId', isEqualTo: userId)
              .get(const GetOptions(source: Source.server));
          await _offlineStore.mergeRemoteNotes(
            userId,
            snapshot.docs.map(Note.fromFirestore).toList(growable: false),
          );
        } on FirebaseException catch (error, stackTrace) {
          debugPrint(
            '[NotesService] event=remote_pull_deferred userId=$userId '
            'error=$error\n$stackTrace',
          );
        }
      }
    } finally {
      _syncingUsers.remove(userId);
    }
  }

  Future<String> uploadNoteImage({
    required String userId,
    required String noteId,
    required XFile image,
  }) async {
    final safeName = _safeFileName(image.name);
    final nameParts = safeName.split('.');
    final extension = nameParts.length > 1
        ? nameParts.last.toLowerCase()
        : 'jpg';
    final uploadName = nameParts.length > 1 ? safeName : '$safeName.jpg';
    final path =
        'users/$userId/notes/$noteId/images/'
        '${DateTime.now().millisecondsSinceEpoch}_$uploadName';
    final reference = _storage.ref().child(path);
    final metadata = SettableMetadata(
      contentType: image.mimeType ?? _contentTypeFor(extension),
    );
    debugPrint(
      '[NotesService] event=image_upload_start noteId=$noteId '
      'name=$safeName path=$path',
    );
    try {
      final bytes = await image.readAsBytes();
      await reference.putData(bytes, metadata);
      final url = await reference.getDownloadURL();
      debugPrint('[NotesService] event=image_upload_success noteId=$noteId');
      return url;
    } catch (error, stackTrace) {
      debugPrint(
        '[NotesService] event=image_upload_failure noteId=$noteId '
        'error=$error\n$stackTrace',
      );
      rethrow;
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

    _remoteSubscriptions[userId] = _notesCollection
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (snapshot.metadata.isFromCache) {
              return;
            }
            unawaited(
              _offlineStore.mergeRemoteNotes(
                userId,
                snapshot.docs.map(Note.fromFirestore).toList(growable: false),
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              '[NotesService] event=remote_listener_deferred userId=$userId '
              'error=$error\n$stackTrace',
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

  Future<bool> _pushMutation(PendingNoteMutation mutation) async {
    try {
      final reference = _notesCollection.doc(mutation.noteId);
      if (mutation.type == PendingNoteMutationType.delete) {
        await reference.delete();
      } else {
        final payload = mutation.payload;
        if (payload == null) {
          throw StateError('An upsert mutation requires a note payload.');
        }
        await reference.set(
          Note.fromLocalMap(payload).toMap(),
          SetOptions(merge: true),
        );
      }
      await _offlineStore.removeMutation(mutation.id);
      return true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[NotesService] event=mutation_queued noteId=${mutation.noteId} '
        'type=${mutation.type.name} error=$error\n$stackTrace',
      );
      return false;
    }
  }

  PendingNoteMutation _upsertMutation(Note note) {
    return PendingNoteMutation(
      id: _mutationId(note.id),
      userId: note.userId,
      noteId: note.id,
      type: PendingNoteMutationType.upsert,
      payload: note.toLocalMap(),
      createdAt: DateTime.now(),
    );
  }

  String _mutationId(String noteId) {
    return '${DateTime.now().microsecondsSinceEpoch}-$noteId';
  }

  List<String> _mergedTags(Iterable<String> explicitTags, String content) {
    final tags = <String>{};
    for (final tag in explicitTags) {
      final normalized = tag.trim();
      if (normalized.isNotEmpty) {
        tags.add(normalized);
      }
    }
    tags.addAll(TagParser.extractTags(content));
    return tags.toList();
  }

  String _safeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return normalized.isEmpty ? 'image.jpg' : normalized;
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }
}
