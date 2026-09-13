import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/attention/data/attention_engine.dart';
import 'package:pulse/features/attention/models/attention_plan.dart';
import 'package:pulse/features/attention/models/attention_preferences.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const engine = AttentionEngine();
  final now = DateTime(2026, 9, 13, 10);

  Task task(String id, DateTime dueAt) => Task(
    id: id,
    userId: 'u1',
    title: 'Task $id',
    isCompleted: false,
    sourceNoteId: 'n1',
    sourceLineIndex: 0,
    dueAt: dueAt,
  );

  test('schedules morning and closing routines', () {
    final result = engine.build(
      now: now,
      preferences: const AttentionPreferences(quietHoursEnabled: false),
      tasks: const [],
      replanning: null,
    );
    expect(
      result.plans.where((p) => p.kind == AttentionKind.morningPulse),
      hasLength(1),
    );
    expect(
      result.plans.where((p) => p.kind == AttentionKind.dailyClosing),
      hasLength(1),
    );
    expect(
      result.plans
          .firstWhere((p) => p.kind == AttentionKind.morningPulse)
          .scheduledAt,
      DateTime(2026, 9, 14, 8),
    );
  });

  test('schedules at most three imminent deadline cues', () {
    final result = engine.build(
      now: now,
      preferences: const AttentionPreferences(
        morningPulseEnabled: false,
        dailyClosingEnabled: false,
        quietHoursEnabled: false,
      ),
      tasks: [
        task('a', now.add(const Duration(hours: 2))),
        task('b', now.add(const Duration(days: 1))),
        task('c', now.add(const Duration(days: 2))),
        task('d', now.add(const Duration(days: 3))),
      ],
      replanning: null,
    );
    expect(
      result.plans.where((p) => p.kind == AttentionKind.deadline),
      hasLength(3),
    );
  });

  test('overdue task is resurfaced shortly instead of dropped', () {
    final result = engine.build(
      now: now,
      preferences: const AttentionPreferences(
        morningPulseEnabled: false,
        dailyClosingEnabled: false,
        quietHoursEnabled: false,
      ),
      tasks: [task('late', now.subtract(const Duration(days: 1)))],
      replanning: null,
    );
    final plan = result.plans.single;
    expect(plan.title, contains('Overdue'));
    expect(plan.scheduledAt, now.add(const Duration(minutes: 2)));
  });

  test('quiet hours defer a deadline cue', () {
    final late = DateTime(2026, 9, 13, 23);
    final result = engine.build(
      now: late,
      preferences: const AttentionPreferences(
        morningPulseEnabled: false,
        dailyClosingEnabled: false,
      ),
      tasks: [task('late', late.subtract(const Duration(hours: 1)))],
      replanning: null,
    );
    expect(result.plans.single.scheduledAt, DateTime(2026, 9, 14, 7));
  });

  test('same schedule issue signature is throttled for six hours', () {
    final overview = ReplanningOverview(
      generatedAt: now,
      horizonEnd: now.add(const Duration(days: 7)),
      issues: [
        const ReplanningIssue(
          id: 'issue-1',
          kind: ReplanningIssueKind.calendarConflict,
          title: 'Conflict',
          message: 'Conflict',
        ),
      ],
      calendarConflictsChecked: true,
    );
    final first = engine.build(
      now: now,
      preferences: const AttentionPreferences(
        morningPulseEnabled: false,
        dailyClosingEnabled: false,
        deadlineAlertsEnabled: false,
        quietHoursEnabled: false,
      ),
      tasks: const [],
      replanning: overview,
    );
    expect(first.plans, hasLength(1));
    final second = engine.build(
      now: now.add(const Duration(hours: 2)),
      preferences: const AttentionPreferences(
        morningPulseEnabled: false,
        dailyClosingEnabled: false,
        deadlineAlertsEnabled: false,
        quietHoursEnabled: false,
      ),
      tasks: const [],
      replanning: overview,
      lastIssueSignature: first.issueSignature,
      lastIssueAlertAt: now,
    );
    expect(second.plans, isEmpty);
  });

  test('schedule issue is eligible again after throttle window', () {
    final overview = ReplanningOverview(
      generatedAt: now,
      horizonEnd: now.add(const Duration(days: 7)),
      issues: [
        const ReplanningIssue(
          id: 'issue-2',
          kind: ReplanningIssueKind.urgentCapacity,
          title: 'Capacity',
          message: 'Capacity',
        ),
      ],
      calendarConflictsChecked: true,
    );
    final result = engine.build(
      now: now.add(const Duration(hours: 7)),
      preferences: const AttentionPreferences(
        morningPulseEnabled: false,
        dailyClosingEnabled: false,
        deadlineAlertsEnabled: false,
        quietHoursEnabled: false,
      ),
      tasks: const [],
      replanning: overview,
      lastIssueSignature: 'issue-2',
      lastIssueAlertAt: now,
    );
    expect(result.plans.single.kind, AttentionKind.scheduleIssue);
  });

  test('disabled attention produces no plans', () {
    final result = engine.build(
      now: now,
      preferences: const AttentionPreferences(enabled: false),
      tasks: [task('a', now.add(const Duration(hours: 1)))],
      replanning: null,
    );
    expect(result.plans, isEmpty);
  });
}
