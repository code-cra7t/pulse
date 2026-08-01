import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/notes/models/note.dart';
import 'offline_database_factory.dart';
import 'pending_note_mutation.dart';

typedef OpenOfflineDatabase = Future<Database> Function();

class OfflineNoteStore {
  OfflineNoteStore({OpenOfflineDatabase? openDatabase})
    : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, dynamic>> _notesStore =
      stringMapStoreFactory.store('notes');
  final StoreRef<String, Map<String, dynamic>> _mutationsStore =
      stringMapStoreFactory.store('pending_note_mutations');
  final Map<String, StreamController<List<Note>>> _controllers = {};

  Future<Database>? _databaseFuture;

  Future<Database> get _database {
    return _databaseFuture ??= _openDatabase();
  }

  String _noteKey(String userId, String noteId) => '$userId::$noteId';

  Stream<List<Note>> watchNotes(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<List<Note>>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );

    unawaited(_emit(userId));
    return controller.stream;
  }

  Future<List<Note>> readNotes(String userId) async {
    final database = await _database;
    final snapshots = await _notesStore.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [
          SortOrder('isPinned', false),
          SortOrder('updatedAtMs', false),
          SortOrder('createdAtMs', false),
        ],
      ),
    );

    return snapshots
        .map((snapshot) => Note.fromLocalMap(snapshot.value))
        .toList(growable: false);
  }

  Future<void> stageUpsert(Note note, PendingNoteMutation mutation) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _notesStore
          .record(_noteKey(note.userId, note.id))
          .put(transaction, note.toLocalMap());
      await _replacePendingMutation(transaction, mutation);
    });
    await _emit(note.userId);
  }

  Future<void> stageDelete(
    String userId,
    String noteId,
    PendingNoteMutation mutation,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _notesStore.record(_noteKey(userId, noteId)).delete(transaction);
      await _replacePendingMutation(transaction, mutation);
    });
    await _emit(userId);
  }

  Future<void> mergeRemoteNotes(String userId, List<Note> remoteNotes) async {
    final database = await _database;

    await database.transaction((transaction) async {
      final pendingSnapshots = await _mutationsStore.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      final protectedNoteIds = {
        for (final snapshot in pendingSnapshots)
          snapshot.value['noteId'] as String? ?? '',
      };
      final localSnapshots = await _notesStore.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );

      for (final snapshot in localSnapshots) {
        final noteId = snapshot.value['id'] as String? ?? '';
        if (!protectedNoteIds.contains(noteId)) {
          await _notesStore.record(snapshot.key).delete(transaction);
        }
      }

      for (final note in remoteNotes) {
        if (protectedNoteIds.contains(note.id)) {
          continue;
        }
        await _notesStore
            .record(_noteKey(userId, note.id))
            .put(transaction, note.toLocalMap());
      }
    });

    await _emit(userId);
  }

  Future<List<PendingNoteMutation>> pendingMutations(String userId) async {
    final database = await _database;
    final snapshots = await _mutationsStore.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('createdAtMs')],
      ),
    );

    return snapshots
        .map((snapshot) => PendingNoteMutation.fromLocalMap(snapshot.value))
        .toList(growable: false);
  }

  Future<void> removeMutation(String mutationId) async {
    final database = await _database;
    await _mutationsStore.record(mutationId).delete(database);
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
    PendingNoteMutation mutation,
  ) async {
    final existing = await _mutationsStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('userId', mutation.userId),
          Filter.equals('noteId', mutation.noteId),
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
    controller.add(await readNotes(userId));
  }
}
