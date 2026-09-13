import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/automation/models/automation_safety_preferences.dart';
import 'package:pulse/features/automation/presentation/automation_safety_sheet.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  testWidgets(
    'trusted automation safety sheet fits 320 px and saves controls',
    (tester) async {
      AutomationSafetyPreferences? result;
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final project = Project(
        id: 'project-1',
        userId: 'user',
        name: 'Exam prep',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      final task = Task(
        id: 'task-1',
        userId: 'user',
        title: 'Review chapter one',
        isCompleted: false,
        sourceNoteId: 'note-1',
        sourceLineIndex: 0,
        projectId: project.id,
        isFlexible: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAutomationSafetySheet(
                    context: context,
                    initial: const AutomationSafetyPreferences(),
                    tasks: [task],
                    projects: [project],
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

      expect(find.text('Trusted automation safety'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('trusted-automation-pause-toggle')),
      );
      await tester.pumpAndSettle();

      final taskToggle = find.byKey(const ValueKey('automation-task-task-1'));
      await tester.ensureVisible(taskToggle);
      await tester.tap(taskToggle);
      await tester.pumpAndSettle();

      final projectToggle = find.byKey(
        const ValueKey('automation-project-project-1'),
      );
      await tester.ensureVisible(projectToggle);
      await tester.tap(projectToggle);
      await tester.pumpAndSettle();

      final save = find.text('Save safety controls');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(result?.paused, isTrue);
      expect(result?.excludedTaskIds, {'task-1'});
      expect(result?.excludedProjectIds, {'project-1'});
      expect(tester.takeException(), isNull);
    },
  );
}
