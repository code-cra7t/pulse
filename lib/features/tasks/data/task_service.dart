import '../../notes/data/notes_service.dart';
import '../models/task_metadata_update.dart';
import 'task_metadata_editor.dart';

class TaskService {
  TaskService(this._notesService);

  final NotesService _notesService;

  Future<void> updateMetadata({
    required String userId,
    required String noteId,
    required String taskId,
    required TaskMetadataUpdate update,
  }) async {
    final note = await _notesService.readLocalNote(userId, noteId);
    if (note == null) {
      throw StateError('Note $noteId was not found for task $taskId.');
    }

    final updatedNote = TaskMetadataEditor.apply(
      note: note,
      taskId: taskId,
      update: update,
    );
    await _notesService.updateNote(updatedNote);
  }

  /// Clears references to [projectId] from all locally known note-backed Tasks.
  ///
  /// Each affected Note remains the source of truth and is staged through the
  /// normal offline-first Notes mutation path.
  Future<int> clearProjectAssignments({
    required String userId,
    required String projectId,
  }) async {
    final notes = await _notesService.readLocalNotes(userId);
    var clearedCount = 0;

    for (final note in notes) {
      final matchingCount = note.taskIdentities
          .where((identity) => identity.projectId == projectId)
          .length;
      if (matchingCount == 0) {
        continue;
      }

      final updatedNote = TaskMetadataEditor.clearProjectAssignments(
        note: note,
        projectId: projectId,
      );
      await _notesService.updateNote(updatedNote);
      clearedCount += matchingCount;
    }

    return clearedCount;
  }
}
