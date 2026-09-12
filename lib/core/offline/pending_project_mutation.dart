enum PendingProjectMutationType {
  upsert,
  delete;

  static PendingProjectMutationType fromValue(String? value) {
    return PendingProjectMutationType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PendingProjectMutationType.upsert,
    );
  }
}

class PendingProjectMutation {
  const PendingProjectMutation({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String projectId;
  final PendingProjectMutationType type;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'projectId': projectId,
      'type': type.name,
      'payload': payload,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PendingProjectMutation.fromLocalMap(Map<String, dynamic> map) {
    return PendingProjectMutation(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      type: PendingProjectMutationType.fromValue(map['type'] as String?),
      payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtMs'] as int? ?? 0,
      ),
    );
  }
}
