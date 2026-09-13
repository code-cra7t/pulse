import '../../scheduling/models/replanning_overview.dart';
import '../../tasks/models/task.dart';
import '../models/attention_plan.dart';
import '../models/attention_preferences.dart';

class AttentionEngineResult {
  const AttentionEngineResult({required this.plans, this.issueSignature});
  final List<AttentionNotificationPlan> plans;
  final String? issueSignature;
}

class AttentionEngine {
  const AttentionEngine();

  AttentionEngineResult build({
    required DateTime now,
    required AttentionPreferences preferences,
    required List<Task> tasks,
    required ReplanningOverview? replanning,
    String? lastIssueSignature,
    DateTime? lastIssueAlertAt,
  }) {
    if (!preferences.enabled) return const AttentionEngineResult(plans: []);
    final plans = <AttentionNotificationPlan>[];

    if (preferences.morningPulseEnabled) {
      final at = _nextDaily(now, preferences.morningMinutes, preferences);
      plans.add(
        AttentionNotificationPlan(
          id: 1810000001,
          kind: AttentionKind.morningPulse,
          title: 'Morning Pulse',
          body: 'See what deserves your attention today.',
          scheduledAt: at,
          destination: AttentionDestination.pulse,
          repeatDaily: true,
        ),
      );
    }

    if (preferences.dailyClosingEnabled) {
      final at = _nextDaily(now, preferences.closingMinutes, preferences);
      plans.add(
        AttentionNotificationPlan(
          id: 1810000002,
          kind: AttentionKind.dailyClosing,
          title: 'Daily Closing',
          body: 'Review what moved forward and what still needs attention.',
          scheduledAt: at,
          destination: AttentionDestination.pulse,
          repeatDaily: true,
        ),
      );
    }

    if (preferences.deadlineAlertsEnabled) {
      final open =
          tasks
              .where((task) => !task.isCompleted && task.dueAt != null)
              .toList()
            ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
      for (final task in open.take(3)) {
        final due = task.dueAt!;
        if (due.isAfter(now.add(const Duration(days: 7)))) break;
        var at = due.subtract(const Duration(hours: 24));
        if (!at.isAfter(now)) at = now.add(const Duration(minutes: 2));
        at = preferences.nextAllowed(at);
        if (!at.isBefore(due) && due.isAfter(now)) continue;
        final overdue = due.isBefore(now);
        plans.add(
          AttentionNotificationPlan(
            id: 1820000000 + _stableId(task.id, 9000000),
            kind: AttentionKind.deadline,
            title: overdue
                ? 'Overdue: ${task.title}'
                : 'Due soon: ${task.title}',
            body: overdue
                ? 'This task is overdue. Review it in Plan.'
                : 'This is due within 24 hours.',
            scheduledAt: at,
            destination: AttentionDestination.plan,
          ),
        );
      }
    }

    String? issueSignature;
    if (preferences.scheduleAlertsEnabled &&
        replanning?.needsAttention == true) {
      final ids = replanning!.issues.map((issue) => issue.id).toList()..sort();
      issueSignature = ids.join('|');
      final throttled =
          issueSignature == lastIssueSignature &&
          lastIssueAlertAt != null &&
          now.difference(lastIssueAlertAt) < const Duration(hours: 6);
      if (!throttled) {
        plans.add(
          AttentionNotificationPlan(
            id: 1810000010,
            kind: AttentionKind.scheduleIssue,
            title: 'Your schedule needs attention',
            body: _scheduleIssueBody(replanning),
            scheduledAt: preferences.nextAllowed(
              now.add(const Duration(minutes: 1)),
            ),
            destination: AttentionDestination.plan,
          ),
        );
      }
    }

    return AttentionEngineResult(
      plans: List.unmodifiable(plans),
      issueSignature: issueSignature,
    );
  }

  String _scheduleIssueBody(ReplanningOverview overview) {
    if (overview.conflictCount > 0) {
      return '${overview.conflictCount} schedule conflict${overview.conflictCount == 1 ? '' : 's'} need review.';
    }
    if (overview.pastBlockReviewCount > 0) {
      return '${overview.pastBlockReviewCount} past block${overview.pastBlockReviewCount == 1 ? '' : 's'} need review.';
    }
    if (overview.urgentCapacityCount > 0) {
      return 'Upcoming work may not fit before its deadline.';
    }
    return 'Open Plan to review what changed.';
  }

  DateTime _nextDaily(
    DateTime now,
    int minutes,
    AttentionPreferences preferences,
  ) {
    var at = _atMinutes(now, minutes);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return preferences.nextAllowed(at);
  }

  DateTime _atMinutes(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

  int _stableId(String value, int modulo) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash % modulo;
  }
}
