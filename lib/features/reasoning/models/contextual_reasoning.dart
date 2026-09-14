import '../../projects/models/project.dart';
import '../../tasks/models/task.dart';

enum ContextualReasoningConfidence { high, medium, low }

enum ContextualExecutionWindowKind {
  activeScheduleBlock,
  acceptedScheduleBlock,
  scheduleProposal,
  replanningSuggestion,
  freeAvailability,
}

class ContextualExecutionWindow {
  const ContextualExecutionWindow({
    required this.kind,
    required this.startsAt,
    required this.endsAt,
  });

  final ContextualExecutionWindowKind kind;
  final DateTime startsAt;
  final DateTime endsAt;

  int get minutes => endsAt.difference(startsAt).inMinutes;
}

class ContextualTaskRecommendation {
  const ContextualTaskRecommendation({
    required this.task,
    required this.score,
    required this.reasons,
    this.project,
    this.executionWindow,
    this.downstreamOpenTaskCount = 0,
    this.people = const <String>[],
    this.relatedEvents = const <String>[],
    this.relatedDecisionCount = 0,
  });

  final Task task;
  final Project? project;
  final int score;
  final List<String> reasons;
  final ContextualExecutionWindow? executionWindow;
  final int downstreamOpenTaskCount;
  final List<String> people;
  final List<String> relatedEvents;
  final int relatedDecisionCount;

  String get primaryReason =>
      reasons.isEmpty ? 'Ready to work on' : reasons.first;
}

class ContextualReasoningResult {
  const ContextualReasoningResult({
    required this.generatedAt,
    required this.readyTaskCount,
    required this.blockedTaskCount,
    required this.confidence,
    this.primary,
    this.alternative,
    this.limitations = const <String>[],
  });

  final DateTime generatedAt;
  final ContextualTaskRecommendation? primary;
  final ContextualTaskRecommendation? alternative;
  final int readyTaskCount;
  final int blockedTaskCount;
  final ContextualReasoningConfidence confidence;
  final List<String> limitations;

  bool get hasRecommendation => primary != null;
}
