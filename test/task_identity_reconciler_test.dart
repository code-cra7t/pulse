import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/notes/utils/task_parser.dart';
import 'package:pulse/features/tasks/data/task_identity_reconciler.dart';
import 'package:pulse/features/tasks/models/note_task_identity.dart';

void main() {
  String idFactory(Iterator<String> ids) {
    if (!ids.moveNext()) {
      throw StateError('No more test IDs.');
    }
    return ids.current;
  }

  test('keeps a task identity when lines are inserted above it', () {
    const previous = <NoteTaskIdentity>[
      NoteTaskIdentity(id: 'task-a', lineIndex: 0, text: 'Send report'),
      NoteTaskIdentity(id: 'task-b', lineIndex: 1, text: 'Book room'),
    ];
    final ids = <String>['new-1'].iterator;

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks(
        'Intro text\n- Send report\n- Book room',
      ),
      previousIdentities: previous,
      createId: () => idFactory(ids),
    );

    expect(reconciled.map((item) => item.id), ['task-a', 'task-b']);
    expect(reconciled.map((item) => item.lineIndex), [1, 2]);
  });

  test('new task inserted above does not steal an existing identity', () {
    const previous = <NoteTaskIdentity>[
      NoteTaskIdentity(id: 'task-a', lineIndex: 0, text: 'Existing task'),
    ];
    final ids = <String>['task-new'].iterator;

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks('- New task\n- Existing task'),
      previousIdentities: previous,
      createId: () => idFactory(ids),
    );

    expect(reconciled[0].id, 'task-new');
    expect(reconciled[1].id, 'task-a');
  });

  test('keeps a task identity when completion state changes', () {
    const previous = <NoteTaskIdentity>[
      NoteTaskIdentity(id: 'task-a', lineIndex: 0, text: 'Send report'),
    ];
    final ids = <String>['new-1'].iterator;

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks('- done: Send report'),
      previousIdentities: previous,
      createId: () => idFactory(ids),
    );

    expect(reconciled.single.id, 'task-a');
    expect(reconciled.single.text, 'Send report');
  });

  test('keeps identity for a task edited in place', () {
    const previous = <NoteTaskIdentity>[
      NoteTaskIdentity(id: 'task-a', lineIndex: 2, text: 'Draft report'),
    ];
    final ids = <String>['new-1'].iterator;

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks('Header\nBody\n- Finalize report'),
      previousIdentities: previous,
      createId: () => idFactory(ids),
    );

    expect(reconciled.single.id, 'task-a');
    expect(reconciled.single.text, 'Finalize report');
  });

  test('creates an identity only for genuinely new tasks', () {
    const previous = <NoteTaskIdentity>[
      NoteTaskIdentity(id: 'task-a', lineIndex: 0, text: 'Existing task'),
    ];
    final ids = <String>['task-new'].iterator;

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks('- Existing task\n- New task'),
      previousIdentities: previous,
      createId: () => idFactory(ids),
    );

    expect(reconciled.map((item) => item.id), ['task-a', 'task-new']);
  });

  test('parser hydrates a persisted stable ID without changing task text', () {
    const identities = <NoteTaskIdentity>[
      NoteTaskIdentity(id: 'task-a', lineIndex: 0, text: 'Send report'),
    ];

    final task = TaskParser.extractTasks(
      '- Send report',
      identities: identities,
    ).single;

    expect(task.id, 'task-a');
    expect(task.text, 'Send report');
    expect(task.lineIndex, 0);
  });

  test('reconciliation preserves planning metadata on stable identities', () {
    final dueAt = DateTime(2026, 10, 2, 9);
    final previous = <NoteTaskIdentity>[
      NoteTaskIdentity(
        id: 'task-a',
        lineIndex: 0,
        text: 'Study insurance',
        projectId: 'project-exam',
        dueAt: dueAt,
        priority: PriorityLevel.critical,
        estimatedMinutes: 90,
        isFlexible: false,
      ),
    ];
    final ids = <String>['unused'].iterator;

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks('Intro\n- Study insurance'),
      previousIdentities: previous,
      createId: () => idFactory(ids),
    ).single;

    expect(reconciled.id, 'task-a');
    expect(reconciled.lineIndex, 1);
    expect(reconciled.projectId, 'project-exam');
    expect(reconciled.dueAt, dueAt);
    expect(reconciled.priority, PriorityLevel.critical);
    expect(reconciled.estimatedMinutes, 90);
    expect(reconciled.isFlexible, isFalse);
  });
}
