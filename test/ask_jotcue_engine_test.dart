import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_engine.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/calendar/models/availability_summary.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/scheduling_day_state.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const engine = AskJotCueEngine();
  final now = DateTime(2026, 9, 13, 10);

  Project project({
    String id = 'project',
    String name = 'Life insurance exam',
    DateTime? deadline,
    PriorityLevel priority = PriorityLevel.high,
  }) {
    return Project(
      id: id,
      userId: 'user',
      name: name,
      deadline: deadline ?? DateTime(2026, 10, 2),
      priority: priority,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 12),
    );
  }

  Task task({
    String id = 'task',
    String title = 'Revise chapter 4',
    DateTime? dueAt,
    PriorityLevel priority = PriorityLevel.high,
    int? estimatedMinutes = 90,
    String? projectId = 'project',
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      userId: 'user',
      title: title,
      isCompleted: isCompleted,
      sourceNoteId: 'note-$id',
      sourceLineIndex: 0,
      projectId: projectId,
      dueAt: dueAt,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
    );
  }

  ScheduleBlock block({
    String id = 'block',
    String title = 'Revise chapter 4',
    int startHour = 11,
    int endHour = 12,
    ScheduleBlockStatus status = ScheduleBlockStatus.scheduled,
  }) {
    return ScheduleBlock(
      id: id,
      userId: 'user',
      taskId: 'task',
      title: title,
      startsAt: DateTime(2026, 9, 13, startHour),
      endsAt: DateTime(2026, 9, 13, endHour),
      status: status,
      createdAt: DateTime(2026, 9, 12),
      updatedAt: DateTime(2026, 9, 12),
    );
  }

  AskJotCueContext context({
    List<Task>? tasks,
    List<Project>? projects,
    List<ScheduleBlock>? blocks,
    SchedulingDayState? scheduling,
    ReplanningOverview? replanning,
  }) {
    final resolvedProjects = projects ?? [project()];
    final resolvedTasks = tasks ?? [task(dueAt: DateTime(2026, 9, 13, 18))];
    final resolvedBlocks = blocks ?? [block()];
    final pulse = PulseOverview.build(
      projects: resolvedProjects,
      tasks: resolvedTasks,
      now: now,
    );
    final loop = DailyPulseLoop.build(
      now: now,
      pulse: pulse,
      blocks: resolvedBlocks,
      scheduling: scheduling,
      replanning: replanning,
    );
    return AskJotCueContext(
      now: now,
      pulse: pulse,
      dailyLoop: loop,
      tasks: resolvedTasks,
      projects: resolvedProjects,
      blocks: resolvedBlocks,
      scheduling: scheduling,
      replanning: replanning,
    );
  }

  test(
    'focus question returns ranked Pulse focus instead of recomputing it',
    () {
      final answer = engine.answer(
        query: 'What should I do now?',
        context: context(),
      );

      expect(answer.intent, AskJotCueIntent.focusNow);
      expect(answer.text, contains('Revise chapter 4'));
      expect(answer.text, contains('Due today'));
      expect(answer.text, contains('1h 30m'));
    },
  );

  test(
    'due soon includes a project whose date is today even after midnight',
    () {
      final answer = engine.answer(
        query: 'What is due soon?',
        context: context(
          tasks: const [],
          projects: [project(deadline: DateTime(2026, 9, 13))],
          blocks: const [],
        ),
      );

      expect(answer.intent, AskJotCueIntent.dueSoon);
      expect(answer.text, contains('Life insurance exam project'));
      expect(answer.text, contains('due today'));
    },
  );

  test('overdue answer lists only incomplete overdue tasks', () {
    final answer = engine.answer(
      query: 'Am I behind on anything?',
      context: context(
        tasks: [
          task(id: 'late', title: 'Late report', dueAt: DateTime(2026, 9, 11)),
          task(
            id: 'done',
            title: 'Done report',
            dueAt: DateTime(2026, 9, 10),
            isCompleted: true,
          ),
        ],
      ),
    );

    expect(answer.intent, AskJotCueIntent.overdue);
    expect(answer.text, contains('Late report'));
    expect(answer.text, isNot(contains('Done report')));
  });

  test('capacity answer reports deterministic free and planned minutes', () {
    final preferences = SchedulingPreferences.defaults().copyWith(
      isConfigured: true,
      availableWeekdays: [DateTime.sunday],
    );
    final scheduling = SchedulingDayState(
      date: DateTime(2026, 9, 13),
      preferences: preferences,
      calendarSupported: false,
      calendarAccess: true,
      acceptedBlocks: [block()],
      availability: AvailabilitySummary(
        windowStart: DateTime(2026, 9, 13, 10),
        windowEnd: DateTime(2026, 9, 13, 20),
        busyMinutes: 120,
        freeMinutes: 480,
        freeSlots: const [],
      ),
    );

    final answer = engine.answer(
      query: 'How much time do I have today?',
      context: context(scheduling: scheduling),
    );

    expect(answer.intent, AskJotCueIntent.capacityToday);
    expect(answer.text, contains('8h realistically free'));
    expect(answer.text, contains('1h is already planned or completed'));
  });

  test('next block answer uses accepted schedule state', () {
    final answer = engine.answer(query: "What's next?", context: context());

    expect(answer.intent, AskJotCueIntent.nextBlock);
    expect(answer.text, contains('Revise chapter 4'));
    expect(answer.text, contains('11:00'));
  });

  test('attention combines replanning and overdue signals', () {
    final replanning = ReplanningOverview(
      generatedAt: now,
      horizonEnd: DateTime(2026, 9, 19, 20),
      issues: [
        const ReplanningIssue(
          id: 'review',
          kind: ReplanningIssueKind.pastBlockReview,
          title: 'Review block',
          message: 'Needs review',
        ),
      ],
      calendarConflictsChecked: true,
    );
    final answer = engine.answer(
      query: 'What needs attention?',
      context: context(
        tasks: [task(dueAt: DateTime(2026, 9, 12, 9))],
        replanning: replanning,
      ),
    );

    expect(answer.intent, AskJotCueIntent.needsAttention);
    expect(answer.text, contains('past planning block needs'));
    expect(answer.text, contains('1 overdue task'));
  });

  test('active projects answer includes open task counts', () {
    final answer = engine.answer(
      query: 'Which projects are active?',
      context: context(),
    );

    expect(answer.intent, AskJotCueIntent.projects);
    expect(answer.text, contains('Life insurance exam'));
    expect(answer.text, contains('1 open task'));
  });

  test('unsupported requests are explicitly bounded and read-only', () {
    final answer = engine.answer(
      query: 'Write an email to my lecturer',
      context: context(),
    );

    expect(answer.intent, AskJotCueIntent.unknown);
    expect(answer.text, contains('I don’t safely understand'));
    expect(answer.text, contains('Nothing is changed'));
  });
}
