import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_schedule_block_store.dart';
import 'package:pulse/core/offline/pending_schedule_block_mutation.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_block_sync_conflict.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineScheduleBlockStore store;

  setUp(() {
    final name = 'schedule-sync-store-${DateTime.now().microsecondsSinceEpoch}';
    store = OfflineScheduleBlockStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(name),
    );
  });

  tearDown(() => store.dispose());

  test(
    'legacy revision-zero blocks are queued for first upload once',
    () async {
      final block = _block('legacy', revision: 0);
      await store.upsert(block);

      await store.stageLegacyBlocksForUpload('user');
      await store.stageLegacyBlocksForUpload('user');

      final pending = await store.pendingMutations('user');
      expect(pending, hasLength(1));
      expect(pending.single.blockId, 'legacy');
      expect(pending.single.baseRevision, 0);
    },
  );

  test(
    'remote listener cannot erase unstaged revision-zero legacy blocks',
    () async {
      final legacy = _block('legacy-race', revision: 0);
      await store.upsert(legacy);

      await store.mergeRemoteBlocks('user', const []);

      final blocks = await store.readBlocks('user');
      expect(blocks, hasLength(1));
      expect(blocks.single.id, 'legacy-race');
      expect(blocks.single.revision, 0);
    },
  );

  test(
    'remote merge preserves a block with a pending local mutation',
    () async {
      final local = _block('one', revision: 2);
      final mutation = PendingScheduleBlockMutation(
        id: 'mutation',
        userId: 'user',
        blockId: 'one',
        type: PendingScheduleBlockMutationType.upsert,
        baseRevision: 2,
        payload: local.copyWith(title: 'Local edit').toLocalMap(),
        createdAt: DateTime(2026, 9, 13),
      );
      await store.stageUpsert(local.copyWith(title: 'Local edit'), mutation);

      await store.mergeRemoteBlocks('user', [
        local.copyWith(title: 'Remote edit', revision: 3),
      ]);

      expect((await store.readBlocks('user')).single.title, 'Local edit');
      expect(await store.pendingMutations('user'), hasLength(1));
    },
  );

  test('newer remote scheduling state records a local review item', () async {
    final local = _block('one', revision: 1);
    await store.upsert(local);

    await store.mergeRemoteBlocks('user', [
      local.copyWith(
        startsAt: DateTime(2026, 9, 14, 12),
        endsAt: DateTime(2026, 9, 14, 13),
        revision: 2,
        updatedAt: DateTime(2026, 9, 13, 13),
      ),
    ]);

    final conflicts = await store.readConflicts('user');
    expect(conflicts, hasLength(1));
    expect(conflicts.single.kind, ScheduleBlockSyncConflictKind.remoteChanged);
    expect(conflicts.single.localBlock?.startsAt, DateTime(2026, 9, 14, 9));
    expect(conflicts.single.remoteBlock?.startsAt, DateTime(2026, 9, 14, 12));
  });

  test(
    'new overlapping remote blocks create a sync review instead of staying silent',
    () async {
      final first = _block('first', revision: 1);
      final second = ScheduleBlock(
        id: 'second',
        userId: 'user',
        taskId: 'task-second',
        title: 'Task second',
        startsAt: DateTime(2026, 9, 14, 9, 30),
        endsAt: DateTime(2026, 9, 14, 10, 30),
        createdAt: DateTime(2026, 9, 13, 8),
        updatedAt: DateTime(2026, 9, 13, 9),
        revision: 1,
      );

      await store.mergeRemoteBlocks('user', [first, second]);

      final conflicts = await store.readConflicts('user');
      expect(
        conflicts.where(
          (item) => item.kind == ScheduleBlockSyncConflictKind.remoteOverlap,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'remote deletion of a synced block records review before removal',
    () async {
      final local = _block('gone', revision: 3);
      await store.upsert(local);

      await store.mergeRemoteBlocks('user', const []);

      expect(await store.readBlocks('user'), isEmpty);
      final conflicts = await store.readConflicts('user');
      expect(conflicts, hasLength(1));
      expect(
        conflicts.single.kind,
        ScheduleBlockSyncConflictKind.remoteDeleted,
      );
      expect(conflicts.single.localBlock?.id, 'gone');
    },
  );

  test('dismissConflict removes only the reviewed item', () async {
    final block = _block('one', revision: 2);
    final mutation = PendingScheduleBlockMutation(
      id: 'mutation',
      userId: 'user',
      blockId: 'one',
      type: PendingScheduleBlockMutationType.upsert,
      baseRevision: 1,
      payload: block.toLocalMap(),
      createdAt: DateTime(2026, 9, 13),
    );
    await store.stageUpsert(block, mutation);
    await store.resolveConflict(
      mutation: mutation,
      conflict: ScheduleBlockSyncConflict(
        id: 'conflict',
        userId: 'user',
        blockId: 'one',
        kind: ScheduleBlockSyncConflictKind.remoteChanged,
        detectedAt: DateTime(2026, 9, 13),
        localBlock: block,
        remoteBlock: block.copyWith(revision: 3),
      ),
      remoteBlock: block.copyWith(revision: 3),
    );

    await store.dismissConflict('user', 'conflict');

    expect(await store.readConflicts('user'), isEmpty);
    expect((await store.readBlocks('user')).single.revision, 3);
  });
}

ScheduleBlock _block(String id, {required int revision}) {
  return ScheduleBlock(
    id: id,
    userId: 'user',
    taskId: 'task-$id',
    title: 'Task $id',
    startsAt: DateTime(2026, 9, 14, 9),
    endsAt: DateTime(2026, 9, 14, 10),
    createdAt: DateTime(2026, 9, 13, 8),
    updatedAt: DateTime(2026, 9, 13, 9),
    revision: revision,
  );
}
