import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/offline/offline_schedule_block_store.dart';
import '../../../core/offline/pending_schedule_block_mutation.dart';
import '../models/schedule_block.dart';
import '../models/schedule_block_sync_conflict.dart';
import '../models/schedule_proposal.dart';
import 'schedule_block_remote_store.dart';
import 'schedule_blocks_repository.dart';

class OfflineFirstScheduleBlocksRepository implements ScheduleBlocksRepository {
  OfflineFirstScheduleBlocksRepository(this._remote, this._store);

  final ScheduleBlockRemoteStore _remote;
  final OfflineScheduleBlockStore _store;
  final Map<String, StreamSubscription<List<ScheduleBlock>>>
  _remoteSubscriptions = {};
  final Map<String, Future<void>> _syncFutures = {};
  final Set<String> _syncRequestedUsers = {};

  @override
  Stream<List<ScheduleBlock>> watchBlocks(String userId) {
    _stopWatchingOtherUsers(userId);
    _startRemoteListener(userId);
    unawaited(synchronize(userId));
    return _store.watchBlocks(userId);
  }

  @override
  Future<List<ScheduleBlock>> readBlocks(String userId) {
    return _store.readBlocks(userId);
  }

  @override
  Future<ScheduleBlock> acceptProposal({
    required String userId,
    required ScheduleProposal proposal,
  }) async {
    final existing = await _store.readBlocks(userId);
    final conflicts = existing.any(
      (block) =>
          block.occupiesTime &&
          block.startsAt.isBefore(proposal.endsAt) &&
          block.endsAt.isAfter(proposal.startsAt),
    );
    if (conflicts) {
      throw StateError(
        'That time is no longer free. Refresh the schedule proposal.',
      );
    }

    final now = DateTime.now();
    final block = ScheduleBlock(
      id: '${now.microsecondsSinceEpoch}-${proposal.taskId}',
      userId: userId,
      taskId: proposal.taskId,
      title: proposal.title,
      projectId: proposal.projectId,
      startsAt: proposal.startsAt,
      endsAt: proposal.endsAt,
      createdAt: now,
      updatedAt: now,
      revision: 0,
    );
    await _stageUpsert(block, baseRevision: 0);
    unawaited(synchronize(userId));
    return block;
  }

  @override
  Future<void> updateStatus({
    required ScheduleBlock block,
    required ScheduleBlockStatus status,
  }) async {
    final current = await _requireCurrent(block);
    final baseRevision = await _baseRevision(current);
    final updated = current.copyWith(status: status, updatedAt: DateTime.now());
    await _stageUpsert(updated, baseRevision: baseRevision);
    unawaited(synchronize(updated.userId));
  }

  @override
  Future<ScheduleBlock> rescheduleBlock({
    required ScheduleBlock block,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('The rescheduled block must end after it starts.');
    }
    final current = await _requireCurrent(block);
    final existing = await _store.readBlocks(block.userId);
    final conflicts = existing.any(
      (other) =>
          other.id != block.id &&
          other.occupiesTime &&
          other.startsAt.isBefore(endsAt) &&
          other.endsAt.isAfter(startsAt),
    );
    if (conflicts) {
      throw StateError(
        'That time is no longer free. Refresh the replanning suggestion.',
      );
    }

    final baseRevision = await _baseRevision(current);
    final updated = current.copyWith(
      startsAt: startsAt,
      endsAt: endsAt,
      status: ScheduleBlockStatus.scheduled,
      updatedAt: DateTime.now(),
    );
    await _stageUpsert(updated, baseRevision: baseRevision);
    unawaited(synchronize(updated.userId));
    return updated;
  }

  @override
  Future<void> deleteBlock(String userId, String blockId) async {
    final current = await _store.readBlock(userId, blockId);
    if (current == null) return;
    final existingMutation = await _store.pendingMutationForBlock(
      userId,
      blockId,
    );
    if (existingMutation?.isUnsyncedCreate == true) {
      await _store.cancelUnsyncedCreate(userId, blockId);
      return;
    }

    final baseRevision = existingMutation?.baseRevision ?? current.revision;
    final mutation = PendingScheduleBlockMutation(
      id: _mutationId(blockId),
      userId: userId,
      blockId: blockId,
      type: PendingScheduleBlockMutationType.delete,
      baseRevision: baseRevision,
      payload: current.toLocalMap(),
      createdAt: DateTime.now(),
    );
    await _store.stageDelete(userId, blockId, mutation);
    unawaited(synchronize(userId));
  }

  @override
  Future<void> clearUser(String userId) {
    return _store.clearUser(userId);
  }

  Future<void> synchronize(String userId) {
    _syncRequestedUsers.add(userId);
    final existing = _syncFutures[userId];
    if (existing != null) return existing;

    final future = _synchronize(userId);
    _syncFutures[userId] = future;
    return future;
  }

  Future<void> _synchronize(String userId) async {
    try {
      syncLoop:
      while (_syncRequestedUsers.remove(userId)) {
        await _store.stageLegacyBlocksForUpload(userId);
        while (true) {
          final pending = await _store.pendingMutations(userId);
          if (pending.isEmpty) break;
          var allPushed = true;
          for (final mutation in pending) {
            if (!await _pushMutation(mutation)) {
              allPushed = false;
              break;
            }
          }
          if (!allPushed) {
            if (_syncRequestedUsers.contains(userId)) continue syncLoop;
            return;
          }
        }

        try {
          await _store.mergeRemoteBlocks(
            userId,
            await _remote.readBlocks(userId),
          );
        } catch (error, stackTrace) {
          debugPrint(
            '[ScheduleSync] event=remote_pull_deferred userId=$userId '
            'error=$error\n$stackTrace',
          );
        }
      }
    } finally {
      _syncFutures.remove(userId);
    }
  }

  Future<void> dispose() async {
    final subscriptions = _remoteSubscriptions.values.toList(growable: false);
    _remoteSubscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await Future.wait(_syncFutures.values.toList(growable: false));
  }

  Future<ScheduleBlock> _requireCurrent(ScheduleBlock requested) async {
    final current = await _store.readBlock(requested.userId, requested.id);
    if (current == null || !_sameSnapshot(current, requested)) {
      throw StateError(
        'This planned block changed on another device. Refresh Plan before editing it.',
      );
    }
    return current;
  }

  Future<int> _baseRevision(ScheduleBlock block) async {
    final pending = await _store.pendingMutationForBlock(
      block.userId,
      block.id,
    );
    return pending?.baseRevision ?? block.revision;
  }

  Future<void> _stageUpsert(ScheduleBlock block, {required int baseRevision}) {
    final mutation = PendingScheduleBlockMutation(
      id: _mutationId(block.id),
      userId: block.userId,
      blockId: block.id,
      type: PendingScheduleBlockMutationType.upsert,
      baseRevision: baseRevision,
      payload: block.toLocalMap(),
      createdAt: DateTime.now(),
    );
    return _store.stageUpsert(block, mutation);
  }

  Future<bool> _pushMutation(PendingScheduleBlockMutation mutation) async {
    try {
      if (mutation.type == PendingScheduleBlockMutationType.delete) {
        await _remote.delete(
          userId: mutation.userId,
          blockId: mutation.blockId,
          baseRevision: mutation.baseRevision,
        );
        await _store.confirmDelete(mutation);
      } else {
        final payload = mutation.payload;
        if (payload == null) {
          throw StateError('Schedule-block upsert requires a payload.');
        }
        final local = ScheduleBlock.fromLocalMap(payload);
        final canonical = await _remote.upsert(
          block: local,
          baseRevision: mutation.baseRevision,
        );
        await _store.confirmUpsert(mutation, canonical);
      }
      return true;
    } on ScheduleBlockRemoteConflict catch (conflict) {
      final localMap = mutation.payload;
      final local = localMap == null
          ? null
          : ScheduleBlock.fromLocalMap(localMap);
      final kind = mutation.baseRevision == 0 && conflict.remoteBlock != null
          ? ScheduleBlockSyncConflictKind.createCollision
          : conflict.remoteBlock == null
          ? ScheduleBlockSyncConflictKind.remoteDeleted
          : ScheduleBlockSyncConflictKind.remoteChanged;
      await _store.resolveConflict(
        mutation: mutation,
        conflict: ScheduleBlockSyncConflict(
          id: _conflictId(mutation.blockId),
          userId: mutation.userId,
          blockId: mutation.blockId,
          kind: kind,
          detectedAt: DateTime.now(),
          localBlock: local,
          remoteBlock: conflict.remoteBlock,
        ),
        remoteBlock: conflict.remoteBlock,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[ScheduleSync] event=mutation_queued blockId=${mutation.blockId} '
        'type=${mutation.type.name} error=$error\n$stackTrace',
      );
      return false;
    }
  }

  void _startRemoteListener(String userId) {
    if (_remoteSubscriptions.containsKey(userId)) return;
    _remoteSubscriptions[userId] = _remote
        .watchBlocks(userId)
        .listen(
          (blocks) => unawaited(_store.mergeRemoteBlocks(userId, blocks)),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              '[ScheduleSync] event=remote_listener_deferred userId=$userId '
              'error=$error\n$stackTrace',
            );
          },
        );
  }

  void _stopWatchingOtherUsers(String activeUserId) {
    final otherIds = _remoteSubscriptions.keys
        .where((userId) => userId != activeUserId)
        .toList(growable: false);
    for (final userId in otherIds) {
      final subscription = _remoteSubscriptions.remove(userId);
      if (subscription != null) unawaited(subscription.cancel());
    }
  }

  String _mutationId(String blockId) =>
      '${DateTime.now().microsecondsSinceEpoch}-$blockId';
  String _conflictId(String blockId) =>
      'conflict-${DateTime.now().microsecondsSinceEpoch}-$blockId';
}

bool _sameSnapshot(ScheduleBlock current, ScheduleBlock requested) {
  return current.id == requested.id &&
      current.taskId == requested.taskId &&
      current.startsAt.millisecondsSinceEpoch ==
          requested.startsAt.millisecondsSinceEpoch &&
      current.endsAt.millisecondsSinceEpoch ==
          requested.endsAt.millisecondsSinceEpoch &&
      current.status == requested.status &&
      current.source == requested.source &&
      current.updatedAt.millisecondsSinceEpoch ==
          requested.updatedAt.millisecondsSinceEpoch &&
      current.revision == requested.revision;
}
