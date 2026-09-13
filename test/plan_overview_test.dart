import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/planning/models/plan_overview.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  final now = DateTime(2026, 9, 12, 12);

  Project project({
    required String id,
    required String name,
    ProjectStatus status = ProjectStatus.active,
    DateTime? deadline,
  }) {
    return Project(
      id: id,
      userId: 'user',
      name: name,
      status: status,
      deadline: deadline,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 10),
    );
  }

  Task task({
    required String id,
    required String title,
    bool completed = false,
    String? projectId,
    DateTime? dueAt,
    PriorityLevel priority = PriorityLevel.none,
  }) {
    return Task(
      id: id,
      userId: 'user',
      title: title,
      isCompleted: completed,
      sourceNoteId: 'note-$id',
      sourceLineIndex: 0,
      projectId: projectId,
      dueAt: dueAt,
      priority: priority,
    );
  }

  test('summarizes projects, progress, due soon, and unassigned tasks', () {
    final overview = PlanOverview.build(
      projects: [
        project(id: 'p1', name: 'Exam', deadline: DateTime(2026, 10, 2)),
        project(id: 'p2', name: 'Agency', status: ProjectStatus.paused),
      ],
      tasks: [
        task(
          id: 't1',
          title: 'Revise chapter',
          projectId: 'p1',
          dueAt: DateTime(2026, 9, 14),
        ),
        task(id: 't2', title: 'Mock exam', completed: true, projectId: 'p1'),
        task(id: 't3', title: 'Follow up application'),
      ],
      now: now,
    );

    expect(overview.activeProjectCount, 1);
    expect(
      overview.openTasks.map((task) => task.id),
      containsAll(['t1', 't3']),
    );
    expect(overview.dueSoonTasks.map((task) => task.id), ['t1']);
    expect(overview.unassignedTasks.map((task) => task.id), ['t3']);
    expect(overview.totalTasksForProject('p1'), 2);
    expect(overview.completedTasksForProject('p1'), 1);
    expect(overview.progressForProject('p1'), 0.5);
  });

  test('orders overdue and dated tasks ahead of undated tasks', () {
    final overview = PlanOverview.build(
      projects: const [],
      tasks: [
        task(id: 'undated', title: 'Undated', priority: PriorityLevel.critical),
        task(id: 'future', title: 'Future', dueAt: DateTime(2026, 9, 15)),
        task(id: 'overdue', title: 'Overdue', dueAt: DateTime(2026, 9, 11)),
      ],
      now: now,
    );

    expect(overview.openTasks.map((task) => task.id).toList(), [
      'overdue',
      'future',
      'undated',
    ]);
    expect(overview.overdueTasks.map((task) => task.id), ['overdue']);
  });
}
