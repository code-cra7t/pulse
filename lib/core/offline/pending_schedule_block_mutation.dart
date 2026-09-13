enum PendingScheduleBlockMutationType {
  upsert,
  delete;

  static PendingScheduleBlockMutationType fromValue(String? value) {
    return PendingScheduleBlockMutationType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PendingScheduleBlockMutationType.upsert,
    );
  }
}

class PendingScheduleBlockMutation {
  const PendingScheduleBlockMutation({
    required this.id,
    required this.userId,
    required this.blockId,
    required this.type,
    required this.baseRevision,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String blockId;
  final PendingScheduleBlockMutationType type;
  final int baseRevision;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  bool get isUnsyncedCreate =>
      type == PendingScheduleBlockMutationType.upsert && baseRevision == 0;

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'userId': userId,
    'blockId': blockId,
    'type': type.name,
    'baseRevision': baseRevision,
    'payload': payload,
    'createdAtMs': createdAt.millisecondsSinceEpoch,
  };

  factory PendingScheduleBlockMutation.fromLocalMap(Map<String, dynamic> map) {
    return PendingScheduleBlockMutation(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      blockId: map['blockId'] as String? ?? '',
      type: PendingScheduleBlockMutationType.fromValue(map['type'] as String?),
      baseRevision: map['baseRevision'] as int? ?? 0,
      payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtMs'] as int? ?? 0,
      ),
    );
  }
}
