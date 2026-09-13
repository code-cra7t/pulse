import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/planning/presentation/plan_screen.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/projects/providers/project_providers.dart';
import 'package:pulse/features/tasks/models/task.dart';
import 'package:pulse/features/tasks/providers/task_providers.dart';

void main() {
  testWidgets('Plan shows project and task foundation without note UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final project = Project(
      id: 'exam',
      userId: 'user',
      name: 'Life insurance exam',
      description: 'Prepare for 2 October',
      priority: PriorityLevel.critical,
      deadline: DateTime(2026, 10, 2),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 12),
    );
    final tasks = [
      Task(
        id: 'task-1',
        userId: 'user',
        title: 'Revise chapter 4',
        isCompleted: false,
        sourceNoteId: 'note-1',
        sourceLineIndex: 2,
        projectId: project.id,
        dueAt: DateTime(2026, 9, 14),
        estimatedMinutes: 90,
      ),
      const Task(
        id: 'task-2',
        userId: 'user',
        title: 'Follow up application',
        isCompleted: false,
        sourceNoteId: 'note-2',
        sourceLineIndex: 1,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsStreamProvider.overrideWith((ref) => Stream.value([project])),
          tasksProvider.overrideWith((ref) => tasks),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(body: PlanScreen(now: DateTime(2026, 9, 12, 12))),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Life insurance exam'), findsNWidgets(2));
    expect(find.text('Revise chapter 4'), findsOneWidget);
    expect(find.text('Follow up application'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Plan explains how projects and tasks appear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsStreamProvider.overrideWith(
            (ref) => Stream.value(const <Project>[]),
          ),
          tasksProvider.overrideWith((ref) => const <Task>[]),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(body: PlanScreen(now: DateTime(2026, 9, 12, 12))),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('No projects yet'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('plan-screen-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('No open tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
