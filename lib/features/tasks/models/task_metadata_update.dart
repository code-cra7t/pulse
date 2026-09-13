import '../../../core/models/priority_level.dart';

class TaskMetadataUpdate {
  const TaskMetadataUpdate({
    this.projectId,
    this.clearProjectId = false,
    this.dueAt,
    this.clearDueAt = false,
    this.priority,
    this.estimatedMinutes,
    this.clearEstimatedMinutes = false,
    this.isFlexible,
    this.dependsOnTaskIds,
    this.waitingFor,
    this.clearWaitingFor = false,
  });

  final String? projectId;
  final bool clearProjectId;
  final DateTime? dueAt;
  final bool clearDueAt;
  final PriorityLevel? priority;
  final int? estimatedMinutes;
  final bool clearEstimatedMinutes;
  final bool? isFlexible;
  final List<String>? dependsOnTaskIds;
  final String? waitingFor;
  final bool clearWaitingFor;

  void validate() {
    if (clearProjectId && projectId != null) {
      throw ArgumentError('projectId cannot be set and cleared together.');
    }
    if (clearDueAt && dueAt != null) {
      throw ArgumentError('dueAt cannot be set and cleared together.');
    }
    if (clearWaitingFor && waitingFor != null) {
      throw ArgumentError('waitingFor cannot be set and cleared together.');
    }
    if (clearEstimatedMinutes && estimatedMinutes != null) {
      throw ArgumentError(
        'estimatedMinutes cannot be set and cleared together.',
      );
    }
    final estimate = estimatedMinutes;
    if (estimate != null && estimate <= 0) {
      throw ArgumentError.value(
        estimate,
        'estimatedMinutes',
        'must be greater than zero',
      );
    }
  }
}
