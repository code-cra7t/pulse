import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_schedule_block_store.dart';
import 'package:pulse/features/scheduling/data/offline_first_schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/data/schedule_block_remote_store.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_block_sync_conflict.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineScheduleBlockStore store;
  late _FakeRemote remote;
  late OfflineFirstScheduleBlocksRepository repository;

  setUp(() {
    final name = 'schedule-sync-repo-${DateTime.now().microsecondsSinceEpoch}';
    store = OfflineScheduleBlockStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(name),
    );
    remote = _FakeRemote()..online = false;
    repository = OfflineFirstScheduleBlocksRepository(remote, store);
  });

  tearDown(() async {
    await repository.dispose();
    await remote.dispose();
    await store.dispose();
  });

  test('offline accepted block uploads and receives revision one', () async {
    await repository.acceptProposal(userId: 'user', proposal: _proposal('one'));
    await Future<void>.delayed(Duration.zero);

    expect((await store.readBlocks('user')).single.revision, 0);
    expect((await store.pendingMutations('user')).single.baseRevision, 0);

    remote.online = true;
    await repository.synchronize('user');

    expect(remote.blocks['one']?.revision, isNull);
    final local = (await store.readBlocks('user')).single;
    expect(local.revision, 1);
    expect(remote.blocks[local.id]?.revision, 1);
    expect(await store.pendingMutations('user'), isEmpty);
  });

  test(
    'newly accepted block can be edited immediately without false stale detection',
    () async {
      final block = await repository.acceptProposal(
        userId: 'user',
        proposal: _proposal('immediate'),
      );

      await repository.updateStatus(
        block: block,
        status: ScheduleBlockStatus.completed,
      );

      expect(
        (await store.readBlocks('user')).single.status,
        ScheduleBlockStatus.completed,
      );
    },
  );

  test('fresh device pulls canonical remote blocks', () async {
    final block = _block('remote', revision: 4);
    remote
      ..online = true
      ..blocks[block.id] = block;

    await repository.synchronize('user');

    final local = (await repository.readBlocks('user')).single;
    expect(local.id, 'remote');
    expect(local.revision, 4);
  });

  test('revision race keeps remote canonical and records conflict', () async {
    final original = _block('one', revision: 1);
    await store.upsert(original);
    remote.blocks['one'] = original;

    await repository.updateStatus(
      block: original,
      status: ScheduleBlockStatus.completed,
    );
    await Future<void>.delayed(Duration.zero);

    remote.blocks['one'] = original.copyWith(
      startsAt: DateTime(2026, 9, 14, 12),
      endsAt: DateTime(2026, 9, 14, 13),
      revision: 2,
      updatedAt: DateTime(2026, 9, 13, 10),
    );
    remote.online = true;
    await repository.synchronize('user');

    final local = (await store.readBlocks('user')).single;
    expect(local.revision, 2);
    expect(local.startsAt, DateTime(2026, 9, 14, 12));
    final conflicts = await store.readConflicts('user');
    expect(conflicts, hasLength(1));
    expect(conflicts.single.kind, ScheduleBlockSyncConflictKind.remoteChanged);
    expect(conflicts.single.localBlock?.status, ScheduleBlockStatus.completed);
  });

  test('remote deletion wins an offline stale update', () async {
    final original = _block('one', revision: 3);
    await store.upsert(original);

    await repository.updateStatus(
      block: original,
      status: ScheduleBlockStatus.completed,
    );
    await Future<void>.delayed(Duration.zero);

    remote.online = true;
    await repository.synchronize('user');

    expect(await store.readBlocks('user'), isEmpty);
    expect(
      (await store.readConflicts('user')).single.kind,
      ScheduleBlockSyncConflictKind.remoteDeleted,
    );
  });

  test('deleting a never-synced create cancels its pending mutation', () async {
    final block = await repository.acceptProposal(
      userId: 'user',
      proposal: _proposal('one'),
    );
    await Future<void>.delayed(Duration.zero);

    await repository.deleteBlock('user', block.id);

    expect(await store.readBlocks('user'), isEmpty);
    expect(await store.pendingMutations('user'), isEmpty);
    expect(remote.deleteCalls, 0);
  });

  test('multiple offline edits retain the original base revision', () async {
    final original = _block('one', revision: 3);
    await store.upsert(original);

    await repository.updateStatus(
      block: original,
      status: ScheduleBlockStatus.completed,
    );
    final afterStatus = (await store.readBlocks('user')).single;
    await repository.rescheduleBlock(
      block: afterStatus,
      startsAt: DateTime(2026, 9, 14, 11),
      endsAt: DateTime(2026, 9, 14, 12),
    );

    final pending = await store.pendingMutations('user');
    expect(pending, hasLength(1));
    expect(pending.single.baseRevision, 3);
    final payload = ScheduleBlock.fromLocalMap(pending.single.payload!);
    expect(payload.startsAt, DateTime(2026, 9, 14, 11));
  });

  test('stale caller snapshot is rejected before mutation staging', () async {
    final original = _block('one', revision: 2);
    await store.upsert(original);
    await store.upsert(original.copyWith(updatedAt: DateTime(2026, 9, 13, 11)));

    await expectLater(
      repository.updateStatus(
        block: original,
        status: ScheduleBlockStatus.completed,
      ),
      throwsStateError,
    );
    expect(await store.pendingMutations('user'), isEmpty);
  });
}

class _FakeRemote implements ScheduleBlockRemoteStore {
  final Map<String, ScheduleBlock> blocks = {};
  final StreamController<List<ScheduleBlock>> _controller =
      StreamController<List<ScheduleBlock>>.broadcast();
  bool online = true;
  int deleteCalls = 0;

  @override
  Stream<List<ScheduleBlock>> watchBlocks(String userId) => _controller.stream;

  @override
  Future<List<ScheduleBlock>> readBlocks(String userId) async {
    if (!online) throw StateError('offline');
    return blocks.values.where((block) => block.userId == userId).toList();
  }

  @override
  Future<ScheduleBlock> upsert({
    required ScheduleBlock block,
    required int baseRevision,
  }) async {
    if (!online) throw StateError('offline');
    final remote = blocks[block.id];
    if ((baseRevision == 0 && remote != null) ||
        (baseRevision > 0 && remote?.revision != baseRevision)) {
      throw ScheduleBlockRemoteConflict(
        blockId: block.id,
        baseRevision: baseRevision,
        remoteBlock: remote,
      );
    }
    final canonical = block.copyWith(revision: baseRevision + 1);
    blocks[block.id] = canonical;
    _controller.add(blocks.values.toList());
    return canonical;
  }

  @override
  Future<void> delete({
    required String userId,
    required String blockId,
    required int baseRevision,
  }) async {
    if (!online) throw StateError('offline');
    deleteCalls += 1;
    final remote = blocks[blockId];
    if (remote == null) return;
    if (remote.revision != baseRevision) {
      throw ScheduleBlockRemoteConflict(
        blockId: blockId,
        baseRevision: baseRevision,
        remoteBlock: remote,
      );
    }
    blocks.remove(blockId);
    _controller.add(blocks.values.toList());
  }

  Future<void> dispose() => _controller.close();
}

ScheduleBlock _block(String id, {required int revision}) => ScheduleBlock(
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

ScheduleProposal _proposal(String taskId) => ScheduleProposal(
  id: 'proposal-$taskId',
  taskId: taskId,
  title: 'Task $taskId',
  startsAt: DateTime(2026, 9, 14, 9),
  endsAt: DateTime(2026, 9, 14, 10),
  reason: 'Test',
  score: 1,
  assumedEffort: false,
);
