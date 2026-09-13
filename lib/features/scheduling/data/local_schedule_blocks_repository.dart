import '../../../core/offline/offline_schedule_block_store.dart';
import '../models/schedule_block.dart';
import '../models/schedule_proposal.dart';
import 'schedule_blocks_repository.dart';

class LocalScheduleBlocksRepository implements ScheduleBlocksRepository {
  LocalScheduleBlocksRepository(this._store);

  final OfflineScheduleBlockStore _store;

  @override
  Stream<List<ScheduleBlock>> watchBlocks(String userId) {
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
    );
    await _store.upsert(block);
    return block;
  }

  @override
  Future<void> updateStatus({
    required ScheduleBlock block,
    required ScheduleBlockStatus status,
  }) {
    return _store.upsert(
      block.copyWith(status: status, updatedAt: DateTime.now()),
    );
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

    final updated = block.copyWith(
      startsAt: startsAt,
      endsAt: endsAt,
      status: ScheduleBlockStatus.scheduled,
      updatedAt: DateTime.now(),
    );
    await _store.upsert(updated);
    return updated;
  }

  @override
  Future<void> deleteBlock(String userId, String blockId) {
    return _store.delete(userId, blockId);
  }

  @override
  Future<void> clearUser(String userId) {
    return _store.clearUser(userId);
  }
}
