import '../models/schedule_block.dart';

abstract interface class ScheduleBlockRemoteStore {
  Stream<List<ScheduleBlock>> watchBlocks(String userId);

  Future<List<ScheduleBlock>> readBlocks(String userId);

  Future<ScheduleBlock> upsert({
    required ScheduleBlock block,
    required int baseRevision,
  });

  Future<void> delete({
    required String userId,
    required String blockId,
    required int baseRevision,
  });
}

class ScheduleBlockRemoteConflict implements Exception {
  const ScheduleBlockRemoteConflict({
    required this.blockId,
    required this.baseRevision,
    this.remoteBlock,
  });

  final String blockId;
  final int baseRevision;
  final ScheduleBlock? remoteBlock;

  @override
  String toString() {
    return 'ScheduleBlockRemoteConflict(blockId: $blockId, '
        'baseRevision: $baseRevision, remoteRevision: '
        '${remoteBlock?.revision})';
  }
}
