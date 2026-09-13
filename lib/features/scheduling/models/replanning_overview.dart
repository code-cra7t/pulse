import 'schedule_block.dart';

/// Reasons JotCue may ask the user to review the current plan.
enum ReplanningIssueKind {
  pastBlockReview,
  calendarConflict,
  outsideAvailability,
  urgentCapacity,
}

class ReplanningSuggestion {
  const ReplanningSuggestion({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;

  int get minutes => endsAt.difference(startsAt).inMinutes;
}

class ReplanningIssue {
  const ReplanningIssue({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    this.taskId,
    this.projectId,
    this.block,
    this.suggestion,
    this.remainingMinutes,
  });

  final String id;
  final ReplanningIssueKind kind;
  final String title;
  final String message;
  final String? taskId;
  final String? projectId;
  final ScheduleBlock? block;
  final ReplanningSuggestion? suggestion;
  final int? remainingMinutes;

  bool get isBlockIssue => block != null;
  bool get isUrgentCapacity => kind == ReplanningIssueKind.urgentCapacity;
}

class ReplanningOverview {
  const ReplanningOverview({
    required this.generatedAt,
    required this.horizonEnd,
    required this.issues,
    required this.calendarConflictsChecked,
  });

  final DateTime generatedAt;
  final DateTime horizonEnd;
  final List<ReplanningIssue> issues;
  final bool calendarConflictsChecked;

  bool get needsAttention => issues.isNotEmpty;

  int get pastBlockReviewCount => issues
      .where((issue) => issue.kind == ReplanningIssueKind.pastBlockReview)
      .length;

  int get conflictCount => issues
      .where(
        (issue) =>
            issue.kind == ReplanningIssueKind.calendarConflict ||
            issue.kind == ReplanningIssueKind.outsideAvailability,
      )
      .length;

  int get urgentCapacityCount => issues
      .where((issue) => issue.kind == ReplanningIssueKind.urgentCapacity)
      .length;
}
