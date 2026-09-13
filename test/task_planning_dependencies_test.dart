import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/planning/presentation/widgets/task_planning_sheet.dart';
import 'package:pulse/features/tasks/models/task.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  testWidgets('dependency controls fit a 320px task planning sheet', (
    tester,
  ) async {
    final task = _task('task-1', 'Submit application');
    final prerequisite = _task('task-2', 'Get transcript');
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showTaskPlanningSheet(
                context: context,
                task: task,
                projects: const [],
                availableTasks: [task, prerequisite],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Dependencies & blockers'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-add-dependency')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-waiting-for')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'planning sheet returns explicit dependency and waiting metadata',
    (tester) async {
      final task = _task('task-1', 'Submit application');
      final prerequisite = _task('task-2', 'Get transcript');
      TaskMetadataUpdate? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await showTaskPlanningSheet(
                    context: context,
                    task: task,
                    projects: const [],
                    availableTasks: [task, prerequisite],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-add-dependency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get transcript').last);
      await tester.enterText(
        find.byKey(const ValueKey('task-waiting-for')),
        'supervisor approval',
      );
      final saveButton = find.text('Save planning details');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(result?.dependsOnTaskIds, ['task-2']);
      expect(result?.waitingFor, 'supervisor approval');
      expect(result?.clearWaitingFor, isFalse);
    },
  );
}

Task _task(String id, String title) => Task(
  id: id,
  userId: 'u',
  title: title,
  isCompleted: false,
  sourceNoteId: 'note-$id',
  sourceLineIndex: 0,
);
