import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/notes/utils/task_parser.dart';
import 'package:pulse/features/tasks/data/task_identity_reconciler.dart';
import 'package:pulse/features/tasks/data/task_metadata_compatibility.dart';
import 'package:pulse/features/tasks/data/task_metadata_editor.dart';
import 'package:pulse/features/tasks/models/note_task_identity.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  test('legacy Note maps remain readable without compatibility fields', () {
    final note = Note.fromLocalMap(<String, dynamic>{
      'id': 'note-1',
      'userId': 'user-1',
      'title': 'Legacy',
      'isPinned': false,
      'createdAtMs': 1,
      'updatedAtMs': 2,
      'tags': <String>[],
      'content': '- Legacy task',
      'color': 0,
      'images': <String>[],
      'taskIdentities': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'task-1',
          'lineIndex': 0,
          'text': 'Legacy task',
        },
      ],
    });

    expect(note.taskMetadataSchemaVersion, 0);
    expect(note.taskMetadataWriteToken, isNull);
    expect(note.usesModernTaskMetadata, isFalse);
    expect(note.toMap(), isNot(contains('taskMetadataSchemaVersion')));
    expect(note.toMap(), isNot(contains('taskMetadataWriteToken')));
  });

  test('modern compatibility fields round-trip through local storage', () {
    final note =
        _note(
          identities: const <NoteTaskIdentity>[
            NoteTaskIdentity(id: 'task-1', lineIndex: 0, text: 'Task'),
          ],
        ).copyWith(
          taskMetadataSchemaVersion: currentTaskMetadataSchemaVersion,
          taskMetadataWriteToken: 'write-token-a',
        );

    final restored = Note.fromLocalMap(note.toLocalMap());

    expect(restored.usesModernTaskMetadata, isTrue);
    expect(
      restored.taskMetadataSchemaVersion,
      currentTaskMetadataSchemaVersion,
    );
    expect(restored.taskMetadataWriteToken, 'write-token-a');
  });

  test('unknown future Task identity fields survive a round-trip', () {
    final identity = NoteTaskIdentity.fromMap(<String, dynamic>{
      'id': 'task-1',
      'lineIndex': 0,
      'text': 'Task',
      'priority': 'high',
      'futureEnergyMode': 'deep',
      'futureScore': 7,
    });

    final map = identity.toMap();

    expect(map['futureEnergyMode'], 'deep');
    expect(map['futureScore'], 7);
    expect(map['priority'], 'high');
  });

  test('editing known metadata preserves unknown future fields', () {
    final identity = NoteTaskIdentity.fromMap(<String, dynamic>{
      'id': 'task-1',
      'lineIndex': 0,
      'text': 'Task',
      'futureEnergyMode': 'deep',
    });

    final edited = identity.copyWith(priority: PriorityLevel.critical);

    expect(edited.extraFields['futureEnergyMode'], 'deep');
    expect(edited.toMap()['futureEnergyMode'], 'deep');
    expect(edited.priority, PriorityLevel.critical);
  });

  test('reconciliation preserves unknown future fields on a stable Task', () {
    final previous = <NoteTaskIdentity>[
      NoteTaskIdentity.fromMap(<String, dynamic>{
        'id': 'task-1',
        'lineIndex': 0,
        'text': 'Task',
        'futureEnergyMode': 'deep',
      }),
    ];

    final reconciled = TaskIdentityReconciler.reconcile(
      currentTasks: TaskParser.extractTasks('Intro\n- Task'),
      previousIdentities: previous,
      createId: () => 'unused',
    ).single;

    expect(reconciled.id, 'task-1');
    expect(reconciled.lineIndex, 1);
    expect(reconciled.extraFields['futureEnergyMode'], 'deep');
  });

  test('modern Note maps include the compatibility guard', () {
    final note = _note().copyWith(
      taskMetadataSchemaVersion: currentTaskMetadataSchemaVersion,
      taskMetadataWriteToken: 'map-token',
    );

    final localMap = note.toLocalMap();
    final remoteMap = note.toMap();

    expect(
      localMap['taskMetadataSchemaVersion'],
      currentTaskMetadataSchemaVersion,
    );
    expect(localMap['taskMetadataWriteToken'], 'map-token');
    expect(
      remoteMap['taskMetadataSchemaVersion'],
      currentTaskMetadataSchemaVersion,
    );
    expect(remoteMap['taskMetadataWriteToken'], 'map-token');
  });

  test(
    'TaskMetadataEditor preserves future fields while editing known metadata',
    () {
      final note = _note(
        identities: <NoteTaskIdentity>[
          NoteTaskIdentity.fromMap(<String, dynamic>{
            'id': 'task-1',
            'lineIndex': 0,
            'text': 'Task',
            'futureEnergyMode': 'deep',
          }),
        ],
      );

      final updated = TaskMetadataEditor.apply(
        note: note,
        taskId: 'task-1',
        update: const TaskMetadataUpdate(priority: PriorityLevel.high),
      );

      expect(updated.taskIdentities.single.priority, PriorityLevel.high);
      expect(updated.taskIdentities.single.toMap()['futureEnergyMode'], 'deep');
    },
  );

  test('legacy queued edit keeps modern remote planning metadata', () {
    final dueAt = DateTime(2026, 10, 20, 9);
    final remote =
        _note(
          content: '- Draft report',
          identities: <NoteTaskIdentity>[
            NoteTaskIdentity(
              id: 'task-1',
              lineIndex: 0,
              text: 'Draft report',
              projectId: 'project-1',
              dueAt: dueAt,
              priority: PriorityLevel.high,
              estimatedMinutes: 60,
              isFlexible: false,
              dependsOnTaskIds: const <String>['task-prereq'],
              waitingFor: 'Supervisor',
            ),
          ],
        ).copyWith(
          taskMetadataSchemaVersion: currentTaskMetadataSchemaVersion,
          taskMetadataWriteToken: 'remote-token',
        );
    final legacyPending = _note(
      content: '- Finalize report',
      identities: const <NoteTaskIdentity>[
        NoteTaskIdentity(id: 'task-1', lineIndex: 0, text: 'Finalize report'),
      ],
    );

    final hardened = TaskMetadataCompatibility.hardenLegacyMutation(
      pendingNote: legacyPending,
      remoteNote: remote,
      createTaskId: () => 'new-task',
      writeToken: 'new-token',
    );

    final task = hardened.taskIdentities.single;
    expect(task.id, 'task-1');
    expect(task.text, 'Finalize report');
    expect(task.projectId, 'project-1');
    expect(task.dueAt, dueAt);
    expect(task.priority, PriorityLevel.high);
    expect(task.estimatedMinutes, 60);
    expect(task.isFlexible, isFalse);
    expect(task.dependsOnTaskIds, ['task-prereq']);
    expect(task.waitingFor, 'Supervisor');
    expect(hardened.usesModernTaskMetadata, isTrue);
    expect(hardened.taskMetadataWriteToken, 'new-token');
  });

  test('legacy queued edit can add a Task without reusing a protected ID', () {
    final remote =
        _note(
          content: '- Existing',
          identities: const <NoteTaskIdentity>[
            NoteTaskIdentity(id: 'task-1', lineIndex: 0, text: 'Existing'),
          ],
        ).copyWith(
          taskMetadataSchemaVersion: currentTaskMetadataSchemaVersion,
          taskMetadataWriteToken: 'remote-token',
        );
    final pending = _note(content: '- Existing\n- Added');

    final ids = <String>['task-new'].iterator;
    final hardened = TaskMetadataCompatibility.hardenLegacyMutation(
      pendingNote: pending,
      remoteNote: remote,
      createTaskId: () {
        ids.moveNext();
        return ids.current;
      },
      writeToken: 'new-token',
    );

    expect(hardened.taskIdentities.map((item) => item.id), [
      'task-1',
      'task-new',
    ]);
  });

  test('legacy hardening never downgrades a future remote schema', () {
    final remote =
        _note(
          identities: <NoteTaskIdentity>[
            NoteTaskIdentity.fromMap(<String, dynamic>{
              'id': 'task-1',
              'lineIndex': 0,
              'text': 'Task',
              'futureEnergyMode': 'deep',
            }),
          ],
        ).copyWith(
          taskMetadataSchemaVersion: 2,
          taskMetadataWriteToken: 'future-token',
        );

    final hardened = TaskMetadataCompatibility.hardenLegacyMutation(
      pendingNote: _note(content: '- Task'),
      remoteNote: remote,
      createTaskId: () => 'unused',
      writeToken: 'new-token',
    );

    expect(hardened.taskMetadataSchemaVersion, 2);
    expect(hardened.taskIdentities.single.toMap()['futureEnergyMode'], 'deep');
  });

  test('already-modern queued Note is not rewritten by hardening', () {
    final modern = _note().copyWith(
      taskMetadataSchemaVersion: currentTaskMetadataSchemaVersion,
      taskMetadataWriteToken: 'modern-token',
    );

    final hardened = TaskMetadataCompatibility.hardenLegacyMutation(
      pendingNote: modern,
      remoteNote: null,
      createTaskId: () => 'unused',
      writeToken: 'replacement-token',
    );

    expect(identical(hardened, modern), isTrue);
    expect(hardened.taskMetadataWriteToken, 'modern-token');
  });
}

Note _note({
  String content = '- Task',
  List<NoteTaskIdentity> identities = const <NoteTaskIdentity>[],
}) {
  return Note(
    id: 'note-1',
    userId: 'user-1',
    title: 'Test',
    isPinned: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    tags: const <String>[],
    content: content,
    color: 0,
    images: const <String>[],
    taskIdentities: identities,
  );
}
