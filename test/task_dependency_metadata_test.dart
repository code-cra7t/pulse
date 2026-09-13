import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/tasks/data/task_metadata_editor.dart';
import 'package:pulse/features/tasks/models/note_task_identity.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  test('legacy identity defaults to no dependencies or waiting blocker', () {
    final identity = NoteTaskIdentity.fromMap({
      'id': 'task-1',
      'lineIndex': 0,
      'text': 'Draft',
    });
    expect(identity.dependsOnTaskIds, isEmpty);
    expect(identity.waitingFor, isNull);
  });

  test('dependency metadata round-trips with normalization', () {
    final identity = NoteTaskIdentity.fromMap({
      'id': 'task-1',
      'lineIndex': 0,
      'text': 'Draft',
      'dependsOnTaskIds': [' a ', 'a', '', 'b'],
      'waitingFor': '  reply  ',
    });
    expect(identity.dependsOnTaskIds, ['a', 'b']);
    expect(identity.waitingFor, 'reply');
    expect(identity.toMap()['dependsOnTaskIds'], ['a', 'b']);
    expect(identity.toMap()['waitingFor'], 'reply');
  });

  test('metadata editor sets dependencies and clears waiting-for text', () {
    final note = Note(
      id: 'note-1',
      userId: 'u',
      title: 'Tasks',
      isPinned: false,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
      tags: const [],
      content: '- [ ] Draft',
      color: 0,
      images: const [],
      taskIdentities: const [
        NoteTaskIdentity(
          id: 'task-1',
          lineIndex: 0,
          text: 'Draft',
          waitingFor: 'reply',
        ),
      ],
    );
    final updated = TaskMetadataEditor.apply(
      note: note,
      taskId: 'task-1',
      update: const TaskMetadataUpdate(
        dependsOnTaskIds: ['a', ' a ', 'b'],
        clearWaitingFor: true,
      ),
    );
    expect(updated.taskIdentities.single.dependsOnTaskIds, ['a', 'b']);
    expect(updated.taskIdentities.single.waitingFor, isNull);
  });
}
