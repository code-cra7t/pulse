import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/priority_level.dart';

enum ProjectStatus {
  active,
  paused,
  completed,
  archived;

  static ProjectStatus fromValue(String? value) {
    return ProjectStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProjectStatus.active,
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.status = ProjectStatus.active,
    this.priority = PriorityLevel.none,
    this.deadline,
    this.targetMinutesPerWeek,
  });

  final String id;
  final String userId;
  final String name;
  final String description;
  final ProjectStatus status;
  final PriorityLevel priority;
  final DateTime? deadline;
  final int? targetMinutesPerWeek;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == ProjectStatus.active;

  Project copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    ProjectStatus? status,
    PriorityLevel? priority,
    Object? deadline = _unchanged,
    Object? targetMinutesPerWeek = _unchanged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      deadline: identical(deadline, _unchanged)
          ? this.deadline
          : deadline as DateTime?,
      targetMinutesPerWeek: identical(targetMinutesPerWeek, _unchanged)
          ? this.targetMinutesPerWeek
          : targetMinutesPerWeek as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Project.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = _dateFromTimestamp(data['createdAt']);
    final updatedAt = _dateFromTimestamp(data['updatedAt']);

    return Project(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: ProjectStatus.fromValue(data['status'] as String?),
      priority: PriorityLevel.fromValue(data['priority'] as String?),
      deadline: _dateFromTimestamp(data['deadline']),
      targetMinutesPerWeek: data['targetMinutesPerWeek'] as int?,
      createdAt:
          createdAt ?? updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory Project.fromLocalMap(Map<String, dynamic> data) {
    return Project(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: ProjectStatus.fromValue(data['status'] as String?),
      priority: PriorityLevel.fromValue(data['priority'] as String?),
      deadline: _dateFromMilliseconds(data['deadlineMs']),
      targetMinutesPerWeek: data['targetMinutesPerWeek'] as int?,
      createdAt:
          _dateFromMilliseconds(data['createdAtMs']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _dateFromMilliseconds(data['updatedAtMs']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'deadline': deadline == null ? null : Timestamp.fromDate(deadline!),
      'targetMinutesPerWeek': targetMinutesPerWeek,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'deadlineMs': deadline?.millisecondsSinceEpoch,
      'targetMinutesPerWeek': targetMinutesPerWeek,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
    };
  }
}

DateTime? _dateFromMilliseconds(Object? value) {
  return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}

DateTime? _dateFromTimestamp(Object? value) {
  return value is Timestamp ? value.toDate() : null;
}

const _unchanged = Object();
