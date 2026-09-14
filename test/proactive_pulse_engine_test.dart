import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/pulse/data/proactive_pulse_engine.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/reasoning/models/contextual_reasoning.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const engine = ProactivePulseEngine();
  final now = DateTime(2026, 9, 14, 9);

  Task task({String id = 'task', String title = 'Submit report'}) => Task(
    id: id,
    userId: 'user',
    title: title,
    isCompleted: false,
    sourceNoteId: 'note-$id',
    sourceLineIndex: 0,
  );

  ScheduleBlock block({
    String id = 'block',
    String taskId = 'task',
    String title = 'Submit report',
    int startHour = 8,
    int endHour = 9,
    ScheduleBlockStatus status = ScheduleBlockStatus.scheduled,
  }) => ScheduleBlock(
    id: id,
    userId: 'user',
    taskId: taskId,
    title: title,
    startsAt: DateTime(2026, 9, 14, startHour),
    endsAt: DateTime(2026, 9, 14, endHour),
    status: status,
    createdAt: DateTime(2026, 9, 13),
    updatedAt: DateTime(2026, 9, 13),
  );

  DailyPulseLoop loop({
    List<ScheduleBlock> todayBlocks = const <ScheduleBlock>[],
    List<ScheduleBlock> completedBlocks = const <ScheduleBlock>[],
    List<ScheduleBlock> missedBlocks = const <ScheduleBlock>[],
    List<ScheduleBlock> unresolvedPastBlocks = const <ScheduleBlock>[],
    List<ScheduleBlock> upcomingBlocks = const <ScheduleBlock>[],
  }) => DailyPulseLoop(
    date: DateTime(2026, 9, 14),
    focusCount: 1,
    focusEstimatedMinutes: 60,
    freeMinutes: 240,
    acceptedMinutes: 0,
    proposedMinutes: 0,
    unscheduledTaskCount: 0,
    replanningIssueCount: 0,
    todayBlocks: todayBlocks,
    completedBlocks: completedBlocks,
    missedBlocks: missedBlocks,
    unresolvedPastBlocks: unresolvedPastBlocks,
    upcomingBlocks: upcomingBlocks,
    completedMinutes: completedBlocks.fold<int>(
      0,
      (sum, item) => sum + item.duration.inMinutes,
    ),
    plannedMinutes: todayBlocks.fold<int>(
      0,
      (sum, item) => sum + item.duration.inMinutes,
    ),
    closingStartsAt: DateTime(2026, 9, 14, 17),
    shouldShowClosing: true,
    upNextBlock: upcomingBlocks.isEmpty ? null : upcomingBlocks.first,
  );

  ContextualReasoningResult reasoning({
    ContextualTaskRecommendation? primary,
    ContextualTaskRecommendation? alternative,
    int ready = 1,
    int blocked = 0,
  }) => ContextualReasoningResult(
    generatedAt: now,
    primary: primary,
    alternative: alternative,
    readyTaskCount: ready,
    blockedTaskCount: blocked,
    confidence: ContextualReasoningConfidence.high,
  );

  ContextualTaskRecommendation recommendation({
    String title = 'Submit report',
    List<String> reasons = const ['Due today', 'High priority'],
    ContextualExecutionWindow? window,
  }) => ContextualTaskRecommendation(
    task: task(title: title),
    score: 1000,
    reasons: reasons,
    executionWindow: window,
  );

  test('morning pulse names the best action, why, and confirmed window', () {
    final snapshot = engine.build(
      now: now,
      reasoning: reasoning(
        primary: recommendation(
          window: ContextualExecutionWindow(
            kind: ContextualExecutionWindowKind.acceptedScheduleBlock,
            startsAt: DateTime(2026, 9, 14, 10),
            endsAt: DateTime(2026, 9, 14, 11),
          ),
        ),
      ),
      loop: loop(),
    );

    expect(snapshot.morningMessage, contains('Start with Submit report'));
    expect(snapshot.morningMessage, contains('Due today · High priority'));
    expect(snapshot.morningMessage, contains('10:00–11:00 today'));
    expect(snapshot.focusMessage, contains('Submit report'));
  });

  test('blocked work is explicitly safe to leave out of focus', () {
    final snapshot = engine.build(
      now: now,
      reasoning: reasoning(primary: recommendation(), blocked: 2),
      loop: loop(),
    );

    expect(snapshot.blockedMessage, contains('2 other open tasks are blocked'));
    expect(snapshot.blockedMessage, contains('stay out of focus'));
    expect(snapshot.attentionMessage, contains('blocked'));
  });

  test('all-blocked state does not invent a next action', () {
    final snapshot = engine.build(
      now: now,
      reasoning: reasoning(primary: null, ready: 0, blocked: 3),
      loop: loop(),
    );

    expect(snapshot.focusMessage, contains('Nothing is ready yet'));
    expect(snapshot.morningMessage, contains('Nothing is ready to start yet'));
    expect(snapshot.timingMessage, isNull);
  });

  test('replanning suggestion becomes a concrete recovery intervention', () {
    final slipped = block(title: 'Write proposal');
    final replanning = ReplanningOverview(
      generatedAt: now,
      horizonEnd: now.add(const Duration(days: 7)),
      issues: [
        ReplanningIssue(
          id: 'recover',
          kind: ReplanningIssueKind.pastBlockReview,
          title: 'Write proposal',
          message: 'Block passed',
          taskId: 'task',
          block: slipped,
          suggestion: ReplanningSuggestion(
            startsAt: DateTime(2026, 9, 14, 14),
            endsAt: DateTime(2026, 9, 14, 15),
          ),
        ),
      ],
      calendarConflictsChecked: true,
    );

    final snapshot = engine.build(
      now: now,
      reasoning: reasoning(primary: recommendation(title: 'Write proposal')),
      loop: loop(todayBlocks: [slipped], unresolvedPastBlocks: [slipped]),
      replanning: replanning,
    );

    expect(snapshot.recoveryMessage, contains('Write proposal slipped'));
    expect(snapshot.recoveryMessage, contains('14:00–15:00 today'));
    expect(snapshot.closingMessage, snapshot.recoveryMessage);
  });

  test(
    'unresolved past block is surfaced without fabricating recovery time',
    () {
      final unresolved = block(title: 'Review draft');
      final snapshot = engine.build(
        now: now,
        reasoning: reasoning(primary: recommendation()),
        loop: loop(
          todayBlocks: [unresolved],
          unresolvedPastBlocks: [unresolved],
        ),
      );

      expect(snapshot.recoveryMessage, contains('ended without a decision'));
      expect(snapshot.recoveryMessage, isNot(contains('Recovery window')));
    },
  );

  test('closing carries the strongest remaining signal after a clean day', () {
    final done = block(
      status: ScheduleBlockStatus.completed,
      title: 'Morning work',
    );
    final snapshot = engine.build(
      now: now,
      reasoning: reasoning(primary: recommendation(title: 'Prepare slides')),
      loop: loop(todayBlocks: [done], completedBlocks: [done]),
    );

    expect(snapshot.closingMessage, contains('closed out'));
    expect(snapshot.closingMessage, contains('Prepare slides'));
  });

  test('no recommendation remains calm and deterministic', () {
    final snapshot = engine.build(
      now: now,
      reasoning: reasoning(primary: null, ready: 0),
      loop: loop(),
    );

    expect(
      snapshot.morningMessage,
      'Your current plan has no strong next action.',
    );
    expect(snapshot.blockedMessage, isNull);
    expect(snapshot.recoveryMessage, isNull);
  });
}
