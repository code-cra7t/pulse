import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/tasks/data/task_metadata_editor.dart';
import 'package:pulse/features/tasks/models/note_task_identity.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  Note buildNote() {
    final now = DateTime(2026, 9, 12);
    return Note(
      id: 'note-1',
      userId: 'user-1',
      title: 'Plan',
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      tags: const [],
      content: '- Draft application',
      color: 0xFFFFF8E1,
      images: const [],
      taskIdentities: const [
        NoteTaskIdentity(id: 'task-1', lineIndex: 0, text: 'Draft application'),
      ],
    );
  }

  test('updates planning metadata without changing visible note content', () {
    final note = buildNote();
    final dueAt = DateTime(2026, 9, 30, 18);

    final updated = TaskMetadataEditor.apply(
      note: note,
      taskId: 'task-1',
      update: TaskMetadataUpdate(
        projectId: 'project-applications',
        dueAt: dueAt,
        priority: PriorityLevel.high,
        estimatedMinutes: 60,
        isFlexible: false,
      ),
    );

    expect(updated.content, note.content);
    expect(updated.title, note.title);
    expect(updated.taskIdentities.single.projectId, 'project-applications');
    expect(updated.taskIdentities.single.dueAt, dueAt);
    expect(updated.taskIdentities.single.priority, PriorityLevel.high);
    expect(updated.taskIdentities.single.estimatedMinutes, 60);
    expect(updated.taskIdentities.single.isFlexible, isFalse);
  });

  test('supports explicitly clearing nullable planning metadata', () {
    final note = buildNote().copyWith(
      taskIdentities: [
        NoteTaskIdentity(
          id: 'task-1',
          lineIndex: 0,
          text: 'Draft application',
          projectId: 'project-applications',
          dueAt: DateTime(2026, 9, 30),
          estimatedMinutes: 60,
        ),
      ],
    );

    final updated = TaskMetadataEditor.apply(
      note: note,
      taskId: 'task-1',
      update: const TaskMetadataUpdate(
        clearProjectId: true,
        clearDueAt: true,
        clearEstimatedMinutes: true,
      ),
    );

    final identity = updated.taskIdentities.single;
    expect(identity.projectId, isNull);
    expect(identity.dueAt, isNull);
    expect(identity.estimatedMinutes, isNull);
  });

  test('rejects non-positive effort estimates', () {
    expect(
      () => TaskMetadataEditor.apply(
        note: buildNote(),
        taskId: 'task-1',
        update: const TaskMetadataUpdate(estimatedMinutes: 0),
      ),
      throwsArgumentError,
    );
  });

  test('clears only task references that point to the deleted project', () {
    final note = buildNote().copyWith(
      content: '- Draft application\n- Keep assignment',
      taskIdentities: [
        const NoteTaskIdentity(
          id: 'task-1',
          lineIndex: 0,
          text: 'Draft application',
          projectId: 'project-delete',
        ),
        const NoteTaskIdentity(
          id: 'task-2',
          lineIndex: 1,
          text: 'Keep assignment',
          projectId: 'project-keep',
        ),
      ],
    );

    final updated = TaskMetadataEditor.clearProjectAssignments(
      note: note,
      projectId: 'project-delete',
    );

    expect(updated.content, note.content);
    expect(updated.taskIdentities.first.projectId, isNull);
    expect(updated.taskIdentities.last.projectId, 'project-keep');
  });
}
