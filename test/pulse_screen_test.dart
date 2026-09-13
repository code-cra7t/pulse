import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/projects/providers/project_providers.dart';
import 'package:pulse/features/pulse/presentation/pulse_screen.dart';
import 'package:pulse/features/tasks/models/task.dart';
import 'package:pulse/features/tasks/providers/task_providers.dart';

void main() {
  testWidgets('Pulse shows personalized focus and planning signals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final project = Project(
      id: 'exam',
      userId: 'user',
      name: 'Life insurance exam',
      deadline: DateTime(2026, 9, 15),
      priority: PriorityLevel.critical,
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
        sourceLineIndex: 1,
        projectId: project.id,
        dueAt: DateTime(2026, 9, 13, 20),
        priority: PriorityLevel.high,
        estimatedMinutes: 90,
      ),
      Task(
        id: 'task-2',
        userId: 'user',
        title: 'Send application',
        isCompleted: false,
        sourceNoteId: 'note-2',
        sourceLineIndex: 2,
        dueAt: DateTime(2026, 9, 12, 18),
      ),
    ];

    var openedPlan = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsStreamProvider.overrideWith((ref) => Stream.value([project])),
          tasksProvider.overrideWith((ref) => tasks),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: PulseScreen(
              now: DateTime(2026, 9, 13, 9),
              displayName: 'Tori Example',
              onOpenPlan: () => openedPlan = true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Good morning, Tori'), findsOneWidget);
    expect(find.text('Your day at a glance'), findsOneWidget);
    expect(find.text('Revise chapter 4'), findsOneWidget);
    expect(find.text('Send application'), findsOneWidget);

    await tester.tap(find.text('Open Plan'));
    expect(openedPlan, isTrue);

    await tester.drag(
      find.byKey(const ValueKey('pulse-screen-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 overdue task'), findsOneWidget);
    expect(find.text('1 project deadline this week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Pulse explains how to create useful signals', (
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
          home: Scaffold(body: PulseScreen(now: DateTime(2026, 9, 13, 19))),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Your focus is clear'), findsOneWidget);
    expect(
      find.text('Nothing is asking for your attention right now.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pulse stays usable on narrow phones', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final project = Project(
      id: 'project',
      userId: 'user',
      name: 'A very long project name that must not overflow the focus card',
      deadline: DateTime(2026, 9, 15),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 12),
    );
    final task = Task(
      id: 'task',
      userId: 'user',
      title: 'A long task title that should wrap safely on a narrow phone',
      isCompleted: false,
      sourceNoteId: 'note',
      sourceLineIndex: 0,
      projectId: project.id,
      dueAt: DateTime(2026, 9, 13, 20),
      estimatedMinutes: 125,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsStreamProvider.overrideWith((ref) => Stream.value([project])),
          tasksProvider.overrideWith((ref) => [task]),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: PulseScreen(
              now: DateTime(2026, 9, 13, 9),
              displayName: 'Tori',
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Good morning, Tori'), findsOneWidget);
    expect(find.textContaining('A long task title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
