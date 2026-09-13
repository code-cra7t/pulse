import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  final now = DateTime(2026, 9, 13, 9);

  Project project({
    required String id,
    required String name,
    DateTime? deadline,
    PriorityLevel priority = PriorityLevel.none,
  }) {
    return Project(
      id: id,
      userId: 'user',
      name: name,
      deadline: deadline,
      priority: priority,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 12),
    );
  }

  Task task({
    required String id,
    required String title,
    DateTime? dueAt,
    PriorityLevel priority = PriorityLevel.none,
    String? projectId,
    int? estimatedMinutes,
    bool completed = false,
  }) {
    return Task(
      id: id,
      userId: 'user',
      title: title,
      isCompleted: completed,
      sourceNoteId: 'note-$id',
      sourceLineIndex: 0,
      dueAt: dueAt,
      priority: priority,
      projectId: projectId,
      estimatedMinutes: estimatedMinutes,
    );
  }

  test('focus prioritizes overdue, due today, and urgent project work', () {
    final exam = project(
      id: 'exam',
      name: 'Insurance exam',
      deadline: DateTime(2026, 9, 15),
      priority: PriorityLevel.critical,
    );
    final overview = PulseOverview.build(
      projects: [exam],
      tasks: [
        task(
          id: 'undated-high',
          title: 'Agency outreach',
          priority: PriorityLevel.high,
        ),
        task(
          id: 'overdue',
          title: 'Submit assignment',
          dueAt: DateTime(2026, 9, 12, 18),
          estimatedMinutes: 45,
        ),
        task(
          id: 'today',
          title: 'Revise chapter 4',
          dueAt: DateTime(2026, 9, 13, 20),
          projectId: exam.id,
          estimatedMinutes: 90,
        ),
        task(
          id: 'later',
          title: 'Prepare mock exam',
          projectId: exam.id,
          priority: PriorityLevel.medium,
        ),
      ],
      now: now,
    );

    expect(overview.focusItems.map((item) => item.task.id).toList(), [
      'overdue',
      'today',
      'later',
    ]);
    expect(overview.focusItems.first.reason, 'Overdue');
    expect(overview.dueTodayCount, 1);
    expect(overview.overdueCount, 1);
    expect(overview.focusEstimatedMinutes, 135);
  });

  test('attention cues surface overdue, deadlines, and undated priorities', () {
    final deadlineProject = project(
      id: 'gradient',
      name: 'GradientLens',
      deadline: DateTime(2026, 9, 15),
    );
    final overview = PulseOverview.build(
      projects: [deadlineProject],
      tasks: [
        task(id: 'overdue', title: 'Late task', dueAt: DateTime(2026, 9, 12)),
        task(
          id: 'undated',
          title: 'Important task',
          priority: PriorityLevel.critical,
        ),
      ],
      now: now,
    );

    expect(
      overview.cues.map((cue) => cue.kind),
      containsAll([
        PulseCueKind.overdue,
        PulseCueKind.deadline,
        PulseCueKind.unplanned,
      ]),
    );
    expect(overview.upcomingProjects.single.id, 'gradient');
  });

  test('completed tasks never enter Pulse focus', () {
    final overview = PulseOverview.build(
      projects: const [],
      tasks: [
        task(
          id: 'done',
          title: 'Finished',
          completed: true,
          dueAt: DateTime(2026, 9, 12),
          priority: PriorityLevel.critical,
        ),
        task(id: 'open', title: 'Still open'),
      ],
      now: now,
    );

    expect(overview.openTaskCount, 1);
    expect(overview.focusItems.single.task.id, 'open');
  });
}
