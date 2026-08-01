enum PendingNoteMutationType {
  upsert,
  delete;

  static PendingNoteMutationType fromValue(String? value) {
    return PendingNoteMutationType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PendingNoteMutationType.upsert,
    );
  }
}

class PendingNoteMutation {
  const PendingNoteMutation({
    required this.id,
    required this.userId,
    required this.noteId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String noteId;
  final PendingNoteMutationType type;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'noteId': noteId,
      'type': type.name,
      'payload': payload,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PendingNoteMutation.fromLocalMap(Map<String, dynamic> map) {
    return PendingNoteMutation(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      noteId: map['noteId'] as String? ?? '',
      type: PendingNoteMutationType.fromValue(map['type'] as String?),
      payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtMs'] as int? ?? 0,
      ),
    );
  }
}
