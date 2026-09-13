import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../features/scheduling/models/schedule_block.dart';
import '../../features/scheduling/models/schedule_block_sync_conflict.dart';
import 'offline_database_factory.dart';
import 'pending_schedule_block_mutation.dart';

typedef OpenScheduleBlocksOfflineDatabase = Future<Database> Function();

class OfflineScheduleBlockStore {
  OfflineScheduleBlockStore({OpenScheduleBlocksOfflineDatabase? openDatabase})
    : _openDatabase = openDatabase ?? openPulseNotesDatabase;

  final OpenScheduleBlocksOfflineDatabase _openDatabase;
  final StoreRef<String, Map<String, dynamic>> _store = stringMapStoreFactory
      .store('schedule_blocks');
  final StoreRef<String, Map<String, dynamic>> _mutationsStore =
      stringMapStoreFactory.store('pending_schedule_block_mutations');
  final StoreRef<String, Map<String, dynamic>> _conflictsStore =
      stringMapStoreFactory.store('schedule_block_sync_conflicts');
  final Map<String, StreamController<List<ScheduleBlock>>> _controllers = {};
  final Map<String, StreamController<List<ScheduleBlockSyncConflict>>>
  _conflictControllers = {};

  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  String _key(String userId, String blockId) => '$userId::$blockId';

  Stream<List<ScheduleBlock>> watchBlocks(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<List<ScheduleBlock>>.broadcast(
        onListen: () => unawaited(_emit(userId)),
      ),
    );
    unawaited(_emit(userId));
    return controller.stream;
  }

  Stream<List<ScheduleBlockSyncConflict>> watchConflicts(String userId) {
    final controller = _conflictControllers.putIfAbsent(
      userId,
      () => StreamController<List<ScheduleBlockSyncConflict>>.broadcast(
        onListen: () => unawaited(_emitConflicts(userId)),
      ),
    );
    unawaited(_emitConflicts(userId));
    return controller.stream;
  }

  Future<List<ScheduleBlock>> readBlocks(String userId) async {
    final database = await _database;
    final snapshots = await _store.find(
      database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('startsAtMs'), SortOrder('createdAtMs')],
      ),
    );
    return snapshots
        .map((snapshot) => ScheduleBlock.fromLocalMap(snapshot.value))
        .where((block) => block.isValid)
        .toList(growable: false);
  }

  Future<ScheduleBlock?> readBlock(String userId, String blockId) async {
    final database = await _database;
    final value = await _store.record(_key(userId, blockId)).get(database);
    return value == null ? null : ScheduleBlock.fromLocalMap(value);
  }

  Future<void> upsert(ScheduleBlock block) async {
    if (!block.isValid) {
      throw ArgumentError('Schedule block end must be after its start.');
    }
    final database = await _database;
    await _store
        .record(_key(block.userId, block.id))
        .put(database, block.toLocalMap());
    await _emit(block.userId);
  }

  Future<void> delete(String userId, String blockId) async {
    final database = await _database;
    await _store.record(_key(userId, blockId)).delete(database);
    await _emit(userId);
  }

  Future<void> stageUpsert(
    ScheduleBlock block,
    PendingScheduleBlockMutation mutation,
  ) async {
    if (!block.isValid || mutation.blockId != block.id) {
      throw ArgumentError('Invalid schedule-block upsert mutation.');
    }
    final database = await _database;
    await database.transaction((transaction) async {
      await _store
          .record(_key(block.userId, block.id))
          .put(transaction, block.toLocalMap());
      await _replacePendingMutation(transaction, mutation);
    });
    await _emit(block.userId);
  }

  Future<void> stageDelete(
    String userId,
    String blockId,
    PendingScheduleBlockMutation mutation,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _store.record(_key(userId, blockId)).delete(transaction);
      await _replacePendingMutation(transaction, mutation);
    });
    await _emit(userId);
  }

  Future<void> cancelUnsyncedCreate(String userId, String blockId) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _store.record(_key(userId, blockId)).delete(transaction);
      final pending = await _pendingForBlock(transaction, userId, blockId);
      if (pending != null) {
        await _mutationsStore.record(pending.id).delete(transaction);
      }
    });
    await _emit(userId);
  }

  Future<PendingScheduleBlockMutation?> pendingMutationForBlock(
    String userId,
    String blockId,
  ) async {
    return _pendingForBlock(await _database, userId, blockId);
  }

  Future<List<PendingScheduleBlockMutation>> pendingMutations(
    String userId,
  ) async {
    final snapshots = await _mutationsStore.find(
      await _database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('createdAtMs')],
      ),
    );
    return snapshots
        .map(
          (snapshot) =>
              PendingScheduleBlockMutation.fromLocalMap(snapshot.value),
        )
        .toList(growable: false);
  }

  Future<void> confirmUpsert(
    PendingScheduleBlockMutation mutation,
    ScheduleBlock canonical,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _store
          .record(_key(canonical.userId, canonical.id))
          .put(transaction, canonical.toLocalMap());
      await _mutationsStore.record(mutation.id).delete(transaction);
    });
    await _emit(canonical.userId);
  }

  Future<void> confirmDelete(PendingScheduleBlockMutation mutation) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _store
          .record(_key(mutation.userId, mutation.blockId))
          .delete(transaction);
      await _mutationsStore.record(mutation.id).delete(transaction);
    });
    await _emit(mutation.userId);
  }

  Future<void> resolveConflict({
    required PendingScheduleBlockMutation mutation,
    required ScheduleBlockSyncConflict conflict,
    required ScheduleBlock? remoteBlock,
  }) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _mutationsStore.record(mutation.id).delete(transaction);
      if (remoteBlock == null) {
        await _store
            .record(_key(mutation.userId, mutation.blockId))
            .delete(transaction);
      } else {
        await _store
            .record(_key(remoteBlock.userId, remoteBlock.id))
            .put(transaction, remoteBlock.toLocalMap());
      }
      await _conflictsStore
          .record(conflict.id)
          .put(transaction, conflict.toLocalMap());
    });
    await _emit(mutation.userId);
    await _emitConflicts(mutation.userId);
  }

  Future<List<ScheduleBlockSyncConflict>> readConflicts(String userId) async {
    final snapshots = await _conflictsStore.find(
      await _database,
      finder: Finder(
        filter: Filter.equals('userId', userId),
        sortOrders: [SortOrder('detectedAtMs', false)],
      ),
    );
    return snapshots
        .map(
          (snapshot) => ScheduleBlockSyncConflict.fromLocalMap(snapshot.value),
        )
        .toList(growable: false);
  }

  Future<void> dismissConflict(String userId, String conflictId) async {
    await _conflictsStore.record(conflictId).delete(await _database);
    await _emitConflicts(userId);
  }

  Future<void> mergeRemoteBlocks(
    String userId,
    List<ScheduleBlock> remoteBlocks,
  ) async {
    final database = await _database;
    await database.transaction((transaction) async {
      final pendingSnapshots = await _mutationsStore.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      final protectedIds = {
        for (final snapshot in pendingSnapshots)
          snapshot.value['blockId'] as String? ?? '',
      };
      final localSnapshots = await _store.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      for (final snapshot in localSnapshots) {
        final local = ScheduleBlock.fromLocalMap(snapshot.value);
        if (local.revision == 0) protectedIds.add(local.id);
      }
      final remoteIds = remoteBlocks.map((block) => block.id).toSet();

      for (final snapshot in localSnapshots) {
        final blockId = snapshot.value['id'] as String? ?? '';
        if (!protectedIds.contains(blockId)) {
          final local = ScheduleBlock.fromLocalMap(snapshot.value);
          if (local.revision > 0 && !remoteIds.contains(blockId)) {
            final conflict = ScheduleBlockSyncConflict(
              id: 'remote-delete-${DateTime.now().microsecondsSinceEpoch}-$blockId',
              userId: userId,
              blockId: blockId,
              kind: ScheduleBlockSyncConflictKind.remoteDeleted,
              detectedAt: DateTime.now(),
              localBlock: local,
            );
            await _conflictsStore
                .record(conflict.id)
                .put(transaction, conflict.toLocalMap());
          }
          await _store.record(snapshot.key).delete(transaction);
        }
      }
      final localById = <String, ScheduleBlock>{
        for (final snapshot in localSnapshots)
          (snapshot.value['id'] as String? ?? ''): ScheduleBlock.fromLocalMap(
            snapshot.value,
          ),
      };

      final changedRemoteIds = <String>{
        for (final block in remoteBlocks)
          if (localById[block.id] == null ||
              block.revision > (localById[block.id]?.revision ?? 0))
            block.id,
      };

      for (final block in remoteBlocks) {
        if (protectedIds.contains(block.id)) continue;
        final previous = localById[block.id];
        if (previous != null &&
            block.revision > previous.revision &&
            _meaningfullyDifferent(previous, block)) {
          final conflict = ScheduleBlockSyncConflict(
            id: 'remote-${DateTime.now().microsecondsSinceEpoch}-${block.id}',
            userId: userId,
            blockId: block.id,
            kind: ScheduleBlockSyncConflictKind.remoteChanged,
            detectedAt: DateTime.now(),
            localBlock: previous,
            remoteBlock: block,
          );
          await _conflictsStore
              .record(conflict.id)
              .put(transaction, conflict.toLocalMap());
        }
        await _store
            .record(_key(userId, block.id))
            .put(transaction, block.toLocalMap());
      }
      final occupying =
          remoteBlocks
              .where((block) => block.occupiesTime)
              .toList(growable: false)
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      for (var i = 0; i < occupying.length; i += 1) {
        for (var j = i + 1; j < occupying.length; j += 1) {
          final first = occupying[i];
          final second = occupying[j];
          if (!second.startsAt.isBefore(first.endsAt)) break;
          if (!first.startsAt.isBefore(second.endsAt)) continue;
          if (!changedRemoteIds.contains(first.id) &&
              !changedRemoteIds.contains(second.id)) {
            continue;
          }
          final orderedIds = [first.id, second.id]..sort();
          final conflict = ScheduleBlockSyncConflict(
            id: 'overlap-${orderedIds[0]}-${orderedIds[1]}-${first.revision}-${second.revision}',
            userId: userId,
            blockId: first.id,
            kind: ScheduleBlockSyncConflictKind.remoteOverlap,
            detectedAt: DateTime.now(),
            localBlock: first,
            remoteBlock: second,
          );
          await _conflictsStore
              .record(conflict.id)
              .put(transaction, conflict.toLocalMap());
        }
      }
    });
    await _emit(userId);
    await _emitConflicts(userId);
  }

  Future<void> stageLegacyBlocksForUpload(String userId) async {
    final database = await _database;
    var changed = false;
    await database.transaction((transaction) async {
      final snapshots = await _store.find(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      for (final snapshot in snapshots) {
        final block = ScheduleBlock.fromLocalMap(snapshot.value);
        if (block.revision != 0) continue;
        final existing = await _pendingForBlock(transaction, userId, block.id);
        if (existing != null) continue;
        final mutation = PendingScheduleBlockMutation(
          id: _mutationId(block.id),
          userId: userId,
          blockId: block.id,
          type: PendingScheduleBlockMutationType.upsert,
          baseRevision: 0,
          payload: block.toLocalMap(),
          createdAt: DateTime.now(),
        );
        await _mutationsStore
            .record(mutation.id)
            .put(transaction, mutation.toLocalMap());
        changed = true;
      }
    });
    if (changed) await _emit(userId);
  }

  Future<void> clearUser(String userId) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _store.delete(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      await _mutationsStore.delete(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
      await _conflictsStore.delete(
        transaction,
        finder: Finder(filter: Filter.equals('userId', userId)),
      );
    });
    await _emit(userId);
    await _emitConflicts(userId);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    for (final controller in _conflictControllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _conflictControllers.clear();

    final databaseFuture = _databaseFuture;
    if (databaseFuture != null) {
      final database = await databaseFuture;
      await database.close();
    }
  }

  Future<PendingScheduleBlockMutation?> _pendingForBlock(
    DatabaseClient database,
    String userId,
    String blockId,
  ) async {
    final snapshots = await _mutationsStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('userId', userId),
          Filter.equals('blockId', blockId),
        ]),
        limit: 1,
      ),
    );
    if (snapshots.isEmpty) return null;
    return PendingScheduleBlockMutation.fromLocalMap(snapshots.first.value);
  }

  Future<void> _replacePendingMutation(
    DatabaseClient database,
    PendingScheduleBlockMutation mutation,
  ) async {
    final existing = await _pendingForBlock(
      database,
      mutation.userId,
      mutation.blockId,
    );
    if (existing != null) {
      await _mutationsStore.record(existing.id).delete(database);
    }
    await _mutationsStore
        .record(mutation.id)
        .put(database, mutation.toLocalMap());
  }

  String _mutationId(String blockId) =>
      '${DateTime.now().microsecondsSinceEpoch}-$blockId';

  Future<void> _emit(String userId) async {
    final controller = _controllers[userId];
    if (controller == null || controller.isClosed) return;
    controller.add(await readBlocks(userId));
  }

  Future<void> _emitConflicts(String userId) async {
    final controller = _conflictControllers[userId];
    if (controller == null || controller.isClosed) return;
    controller.add(await readConflicts(userId));
  }
}

bool _meaningfullyDifferent(ScheduleBlock a, ScheduleBlock b) {
  return a.startsAt != b.startsAt ||
      a.endsAt != b.endsAt ||
      a.status != b.status ||
      a.taskId != b.taskId ||
      a.title != b.title ||
      a.projectId != b.projectId;
}
