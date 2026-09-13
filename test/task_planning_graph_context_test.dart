import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/personal_graph/models/personal_graph.dart';
import 'package:pulse/features/planning/presentation/widgets/task_planning_sheet.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  testWidgets(
    'task planning sheet shows graph-derived related context at 320px',
    (tester) async {
      final now = DateTime.now();
      final task = Task(
        id: 'task-1',
        userId: 'user-1',
        title: 'Prepare application',
        isCompleted: false,
        sourceNoteId: 'note-1',
        sourceLineIndex: 0,
        projectId: 'project-1',
        dueAt: now.add(const Duration(days: 2)),
      );
      final related = PersonalGraphTaskContext(
        task: const PersonalGraphNode(
          id: 'task:task-1',
          type: PersonalGraphNodeType.task,
          entityId: 'task-1',
          label: 'Prepare application',
        ),
        sourceNote: const PersonalGraphNode(
          id: 'note:note-1',
          type: PersonalGraphNodeType.note,
          entityId: 'note-1',
          label: 'Scholarship notes',
        ),
        project: const PersonalGraphNode(
          id: 'project:project-1',
          type: PersonalGraphNodeType.project,
          entityId: 'project-1',
          label: 'Scholarship application',
        ),
        deadline: PersonalGraphNode(
          id: 'deadline:task:task-1',
          type: PersonalGraphNodeType.deadline,
          entityId: 'task:task-1',
          label: 'Prepare application deadline',
          startsAt: now.add(const Duration(days: 2)),
        ),
        scheduleBlocks: [
          PersonalGraphNode(
            id: 'scheduleBlock:block-1',
            type: PersonalGraphNodeType.scheduleBlock,
            entityId: 'block-1',
            label: 'Prepare application',
            startsAt: now.add(const Duration(hours: 2)),
            endsAt: now.add(const Duration(hours: 3)),
            status: 'scheduled',
          ),
        ],
      );

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showTaskPlanningSheet(
                    context: context,
                    task: task,
                    projects: const [],
                    relatedContext: related,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Related context'), findsOneWidget);
      expect(find.textContaining('Note: Scholarship notes'), findsOneWidget);
      expect(
        find.textContaining('Project: Scholarship application'),
        findsOneWidget,
      );
      expect(find.textContaining('Deadline:'), findsOneWidget);
      expect(find.textContaining('Scheduled:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
