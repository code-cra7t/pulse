import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_engine.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_plan_builder.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  final now = DateTime(2026, 9, 14, 10);
  const pulse = PulseOverview(
    focusItems: [],
    cues: [],
    upcomingProjects: [],
    openTaskCount: 2,
    overdueCount: 0,
    dueTodayCount: 0,
    focusEstimatedMinutes: 0,
  );
  final tasks = [
    Task(
      id: 'chapter',
      userId: 'user',
      title: 'Revise chapter 4',
      isCompleted: false,
      sourceNoteId: 'note-1',
      sourceLineIndex: 0,
    ),
    Task(
      id: 'summary',
      userId: 'user',
      title: 'Write summary',
      isCompleted: false,
      sourceNoteId: 'note-2',
      sourceLineIndex: 0,
    ),
  ];
  late final context = AskJotCueContext(
    now: now,
    userId: 'user',
    pulse: pulse,
    dailyLoop: DailyPulseLoop.build(now: now, pulse: pulse, blocks: const []),
    tasks: tasks,
    projects: const [],
    blocks: const [],
  );
  const builder = AskJotCuePlanBuilder(engine: AskJotCueEngine());

  test('builds two existing typed actions from an explicit sequence', () {
    final answer = builder.build(
      query:
          'First mark Revise chapter 4 done, then set Write summary priority to high',
      context: context,
    );

    expect(answer, isNotNull);
    expect(answer!.actionProposal, isNull);
    expect(answer.actionPlan?.steps, hasLength(2));
    expect(
      answer.actionPlan?.steps.first.kind,
      AskJotCueActionKind.taskCompletion,
    );
    expect(
      answer.actionPlan?.steps.last.kind,
      AskJotCueActionKind.taskPriority,
    );
  });

  test('ordinary single-action wording is not reinterpreted as a plan', () {
    final answer = builder.build(
      query: 'Mark Revise chapter 4 done',
      context: context,
    );
    expect(answer, isNull);
  });

  test('explicit plan fails closed when one step is unsupported', () {
    final answer = builder.build(
      query: 'First mark Revise chapter 4 done, then email my lecturer',
      context: context,
    );

    expect(answer, isNotNull);
    expect(answer!.actionPlan, isNull);
    expect(answer.text, contains('Step 2'));
    expect(answer.text, contains('Nothing has changed'));
  });

  test(
    'explicit plan fails closed when one step duplicates an earlier step',
    () {
      final answer = builder.build(
        query:
            'First mark Revise chapter 4 done, then mark Revise chapter 4 done',
        context: context,
      );

      expect(answer, isNotNull);
      expect(answer!.actionPlan, isNull);
      expect(answer.text, contains('duplicates'));
    },
  );

  test('plan is capped at five steps', () {
    final answer = builder.build(
      query:
          'First mark Revise chapter 4 done, '
          'then set Write summary priority high '
          'then set Write summary estimate to 30 minutes '
          'then set Revise chapter 4 estimate to 45 minutes '
          'then set Write summary due tomorrow '
          'then set Revise chapter 4 due tomorrow',
      context: context,
    );

    expect(answer, isNotNull);
    expect(answer!.actionPlan, isNull);
    expect(answer.text, contains('at most 5'));
  });
}
