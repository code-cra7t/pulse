import 'schedule_block.dart';

enum ScheduleBlockSyncConflictKind {
  remoteChanged,
  remoteDeleted,
  createCollision,
  remoteOverlap;

  static ScheduleBlockSyncConflictKind fromValue(String? value) {
    return ScheduleBlockSyncConflictKind.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ScheduleBlockSyncConflictKind.remoteChanged,
    );
  }
}

class ScheduleBlockSyncConflict {
  const ScheduleBlockSyncConflict({
    required this.id,
    required this.userId,
    required this.blockId,
    required this.kind,
    required this.detectedAt,
    this.localBlock,
    this.remoteBlock,
  });

  final String id;
  final String userId;
  final String blockId;
  final ScheduleBlockSyncConflictKind kind;
  final DateTime detectedAt;
  final ScheduleBlock? localBlock;
  final ScheduleBlock? remoteBlock;

  String get title => remoteBlock?.title ?? localBlock?.title ?? 'Planned work';

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'userId': userId,
    'blockId': blockId,
    'kind': kind.name,
    'detectedAtMs': detectedAt.millisecondsSinceEpoch,
    'localBlock': localBlock?.toLocalMap(),
    'remoteBlock': remoteBlock?.toLocalMap(),
  };

  factory ScheduleBlockSyncConflict.fromLocalMap(Map<String, dynamic> map) {
    final localMap = (map['localBlock'] as Map?)?.cast<String, dynamic>();
    final remoteMap = (map['remoteBlock'] as Map?)?.cast<String, dynamic>();
    return ScheduleBlockSyncConflict(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      blockId: map['blockId'] as String? ?? '',
      kind: ScheduleBlockSyncConflictKind.fromValue(map['kind'] as String?),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        map['detectedAtMs'] as int? ?? 0,
      ),
      localBlock: localMap == null
          ? null
          : ScheduleBlock.fromLocalMap(localMap),
      remoteBlock: remoteMap == null
          ? null
          : ScheduleBlock.fromLocalMap(remoteMap),
    );
  }
}
