import '../../notes/models/note.dart';
import '../../notes/utils/task_parser.dart';
import '../models/task.dart';

/// Builds the first-class Task domain view from note-backed task identities.
///
/// Note text remains the source of truth for task title/completion during this
/// foundation phase. Stable identity metadata supplies planning fields such as
/// project, due date, priority, estimate, and flexibility.
class TaskProjector {
  const TaskProjector._();

  static List<Task> fromNotes(Iterable<Note> notes) {
    return [for (final note in notes) ...fromNote(note)];
  }

  static List<Task> fromNote(Note note) {
    if (note.taskIdentities.isEmpty) {
      return const <Task>[];
    }

    final identitiesById = {
      for (final identity in note.taskIdentities) identity.id: identity,
    };
    final parsedTasks = TaskParser.extractTasks(
      note.content,
      identities: note.taskIdentities,
    );

    return [
      for (final parsedTask in parsedTasks)
        if (parsedTask.id != null && identitiesById[parsedTask.id] != null)
          Task(
            id: parsedTask.id!,
            userId: note.userId,
            title: parsedTask.text,
            isCompleted: parsedTask.isCompleted,
            sourceNoteId: note.id,
            sourceLineIndex: parsedTask.lineIndex,
            projectId: identitiesById[parsedTask.id]!.projectId,
            dueAt: identitiesById[parsedTask.id]!.dueAt,
            priority: identitiesById[parsedTask.id]!.priority,
            estimatedMinutes: identitiesById[parsedTask.id]!.estimatedMinutes,
            isFlexible: identitiesById[parsedTask.id]!.isFlexible,
            dependsOnTaskIds: identitiesById[parsedTask.id]!.dependsOnTaskIds,
            waitingFor: identitiesById[parsedTask.id]!.waitingFor,
          ),
    ];
  }
}
