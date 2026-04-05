import 'package:cloud_firestore/cloud_firestore.dart';

import 'repeat_type.dart';

class Reminder {
  const Reminder({
    required this.id,
    required this.userId,
    required this.noteId,
    required this.notePreview,
    required this.scheduledAt,
    required this.isCompleted,
    required this.repeat,
    required this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String noteId;
  final String notePreview;
  final DateTime scheduledAt;
  final bool isCompleted;
  final RepeatType repeat;
  final int notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Reminder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Reminder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      noteId: data['noteId'] as String? ?? '',
      notePreview: data['notePreview'] as String? ?? '',
      scheduledAt:
          (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      repeat: RepeatType.fromValue(data['repeat'] as String?),
      notificationId: data['notificationId'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'noteId': noteId,
      'notePreview': notePreview,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'isCompleted': isCompleted,
      'repeat': repeat.value,
      'notificationId': notificationId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Reminder copyWith({
    String? id,
    String? userId,
    String? noteId,
    String? notePreview,
    DateTime? scheduledAt,
    bool? isCompleted,
    RepeatType? repeat,
    int? notificationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      noteId: noteId ?? this.noteId,
      notePreview: notePreview ?? this.notePreview,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isCompleted: isCompleted ?? this.isCompleted,
      repeat: repeat ?? this.repeat,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
