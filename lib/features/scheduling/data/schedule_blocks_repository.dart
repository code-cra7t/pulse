import '../models/schedule_block.dart';
import '../models/schedule_proposal.dart';

abstract interface class ScheduleBlocksRepository {
  Stream<List<ScheduleBlock>> watchBlocks(String userId);

  Future<List<ScheduleBlock>> readBlocks(String userId);

  Future<ScheduleBlock> acceptProposal({
    required String userId,
    required ScheduleProposal proposal,
  });

  Future<void> updateStatus({
    required ScheduleBlock block,
    required ScheduleBlockStatus status,
  });

  Future<ScheduleBlock> rescheduleBlock({
    required ScheduleBlock block,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<void> deleteBlock(String userId, String blockId);

  Future<void> clearUser(String userId);
}
