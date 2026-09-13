import '../../../core/models/priority_level.dart';

class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.isCompleted,
    required this.sourceNoteId,
    required this.sourceLineIndex,
    this.projectId,
    this.dueAt,
    this.priority = PriorityLevel.none,
    this.estimatedMinutes,
    this.isFlexible = true,
    this.dependsOnTaskIds = const <String>[],
    this.waitingFor,
  });

  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final String sourceNoteId;
  final int sourceLineIndex;
  final String? projectId;
  final DateTime? dueAt;
  final PriorityLevel priority;
  final int? estimatedMinutes;
  final bool isFlexible;
  final List<String> dependsOnTaskIds;
  final String? waitingFor;

  bool get isOverdue {
    final due = dueAt;
    return !isCompleted && due != null && due.isBefore(DateTime.now());
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    bool? isCompleted,
    String? sourceNoteId,
    int? sourceLineIndex,
    Object? projectId = _unchanged,
    Object? dueAt = _unchanged,
    PriorityLevel? priority,
    Object? estimatedMinutes = _unchanged,
    bool? isFlexible,
    List<String>? dependsOnTaskIds,
    Object? waitingFor = _unchanged,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sourceNoteId: sourceNoteId ?? this.sourceNoteId,
      sourceLineIndex: sourceLineIndex ?? this.sourceLineIndex,
      projectId: identical(projectId, _unchanged)
          ? this.projectId
          : projectId as String?,
      dueAt: identical(dueAt, _unchanged) ? this.dueAt : dueAt as DateTime?,
      priority: priority ?? this.priority,
      estimatedMinutes: identical(estimatedMinutes, _unchanged)
          ? this.estimatedMinutes
          : estimatedMinutes as int?,
      isFlexible: isFlexible ?? this.isFlexible,
      dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
      waitingFor: identical(waitingFor, _unchanged)
          ? this.waitingFor
          : waitingFor as String?,
    );
  }
}

const _unchanged = Object();
