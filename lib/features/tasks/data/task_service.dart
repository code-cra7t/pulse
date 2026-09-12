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
}
