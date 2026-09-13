import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/tasks/data/task_projector.dart';
import 'package:pulse/features/tasks/models/note_task_identity.dart';

void main() {
  test('projects note-backed tasks into first-class task domain objects', () {
    final dueAt = DateTime(2026, 10, 2, 9);
    final createdAt = DateTime(2026, 9, 12, 8);
    final updatedAt = DateTime(2026, 9, 12, 9);
    final note = Note(
      id: 'note-1',
      userId: 'user-1',
      title: 'Exam prep',
      isPinned: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: const [],
      content: '- Study chapter 4\n- done: Register for exam',
      color: 0xFFFFF8E1,
      images: const [],
      taskIdentities: [
        NoteTaskIdentity(
          id: 'task-study',
          lineIndex: 0,
          text: 'Study chapter 4',
          projectId: 'project-exam',
          dueAt: dueAt,
          priority: PriorityLevel.high,
          estimatedMinutes: 90,
          isFlexible: true,
        ),
        const NoteTaskIdentity(
          id: 'task-register',
          lineIndex: 1,
          text: 'Register for exam',
        ),
      ],
    );

    final tasks = TaskProjector.fromNote(note);

    expect(tasks, hasLength(2));
    expect(tasks.first.id, 'task-study');
    expect(tasks.first.sourceNoteId, 'note-1');
    expect(tasks.first.sourceLineIndex, 0);
    expect(tasks.first.projectId, 'project-exam');
    expect(tasks.first.dueAt, dueAt);
    expect(tasks.first.priority, PriorityLevel.high);
    expect(tasks.first.estimatedMinutes, 90);
    expect(tasks.first.isFlexible, isTrue);
    expect(tasks.first.isCompleted, isFalse);
    expect(tasks.last.id, 'task-register');
    expect(tasks.last.isCompleted, isTrue);
  });

  test('does not invent unstable IDs for legacy note tasks', () {
    final now = DateTime(2026, 9, 12);
    final note = Note(
      id: 'legacy-note',
      userId: 'user-1',
      title: null,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      tags: const [],
      content: '- Legacy task without identity',
      color: 0xFFFFF8E1,
      images: const [],
    );

    expect(TaskProjector.fromNote(note), isEmpty);
  });
}
