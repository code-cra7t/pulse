import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleBlockStatus {
  scheduled,
  completed,
  skipped;

  static ScheduleBlockStatus fromValue(String? value) {
    return ScheduleBlockStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ScheduleBlockStatus.scheduled,
    );
  }
}

enum ScheduleBlockSource {
  proposal,
  user;

  static ScheduleBlockSource fromValue(String? value) {
    return ScheduleBlockSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => ScheduleBlockSource.proposal,
    );
  }
}

class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.status = ScheduleBlockStatus.scheduled,
    this.source = ScheduleBlockSource.proposal,
    this.revision = 0,
  });

  final String id;
  final String userId;
  final String taskId;
  final String title;
  final String? projectId;
  final DateTime startsAt;
  final DateTime endsAt;
  final ScheduleBlockStatus status;
  final ScheduleBlockSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Monotonic cloud revision. Legacy/device-only blocks use 0 until their
  /// first successful sync, while Firestore-backed blocks start at 1.
  final int revision;

  bool get isValid => endsAt.isAfter(startsAt);
  bool get occupiesTime => status == ScheduleBlockStatus.scheduled;
  bool get countsTowardFocusBudget =>
      status == ScheduleBlockStatus.scheduled ||
      status == ScheduleBlockStatus.completed;
  Duration get duration => endsAt.difference(startsAt);

  ScheduleBlock copyWith({
    String? id,
    String? userId,
    String? taskId,
    String? title,
    Object? projectId = _unchanged,
    DateTime? startsAt,
    DateTime? endsAt,
    ScheduleBlockStatus? status,
    ScheduleBlockSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? revision,
  }) {
    return ScheduleBlock(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      projectId: identical(projectId, _unchanged)
          ? this.projectId
          : projectId as String?,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
    );
  }

  factory ScheduleBlock.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return ScheduleBlock(
      id: data['id'] as String? ?? document.id,
      userId: data['userId'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      projectId: data['projectId'] as String?,
      startsAt: _dateFromTimestamp(data['startsAt']),
      endsAt: _dateFromTimestamp(data['endsAt']),
      status: ScheduleBlockStatus.fromValue(data['status'] as String?),
      source: ScheduleBlockSource.fromValue(data['source'] as String?),
      createdAt: _dateFromTimestamp(data['createdAt']),
      updatedAt: _dateFromTimestamp(data['updatedAt']),
      revision: data['revision'] as int? ?? 0,
    );
  }

  factory ScheduleBlock.fromLocalMap(Map<String, dynamic> data) {
    return ScheduleBlock(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      projectId: data['projectId'] as String?,
      startsAt: DateTime.fromMillisecondsSinceEpoch(
        data['startsAtMs'] as int? ?? 0,
      ),
      endsAt: DateTime.fromMillisecondsSinceEpoch(
        data['endsAtMs'] as int? ?? 0,
      ),
      status: ScheduleBlockStatus.fromValue(data['status'] as String?),
      source: ScheduleBlockSource.fromValue(data['source'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['createdAtMs'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updatedAtMs'] as int? ?? 0,
      ),
      revision: data['revision'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toRemoteMap() {
    return {
      'id': id,
      'userId': userId,
      'taskId': taskId,
      'title': title,
      'projectId': projectId,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'status': status.name,
      'source': source.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'revision': revision,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'taskId': taskId,
      'title': title,
      'projectId': projectId,
      'startsAtMs': startsAt.millisecondsSinceEpoch,
      'endsAtMs': endsAt.millisecondsSinceEpoch,
      'status': status.name,
      'source': source.name,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'revision': revision,
    };
  }
}

DateTime _dateFromTimestamp(Object? value) {
  return value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
}

const _unchanged = Object();
