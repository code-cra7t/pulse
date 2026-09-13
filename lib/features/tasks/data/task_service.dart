import '../../notes/data/notes_service.dart';
import '../../notes/utils/task_parser.dart';
import '../models/task_metadata_update.dart';
import 'task_dependency_analyzer.dart';
import 'task_metadata_editor.dart';
import 'task_projector.dart';

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

    if (update.dependsOnTaskIds != null) {
      final notes = await _notesService.readLocalNotes(userId);
      final proposedNotes = [
        for (final item in notes) item.id == noteId ? updatedNote : item,
      ];
      final proposedTasks = TaskProjector.fromNotes(proposedNotes);
      final knownTaskIds = proposedTasks.map((task) => task.id).toSet();
      final requestedDependencies = update.dependsOnTaskIds!
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (requestedDependencies.contains(taskId)) {
        throw StateError('A task cannot depend on itself.');
      }
      final missing = requestedDependencies.difference(knownTaskIds);
      if (missing.isNotEmpty) {
        throw StateError('One or more prerequisite tasks no longer exist.');
      }
      final analysis = const TaskDependencyAnalyzer().analyze(proposedTasks);
      if (analysis.cycleTaskIds.isNotEmpty) {
        throw StateError('Task dependencies cannot form a cycle.');
      }
    }

    await _notesService.updateNote(updatedNote);
  }

  Future<void> setCompletion({
    required String userId,
    required String noteId,
    required String taskId,
    required bool isCompleted,
  }) async {
    final note = await _notesService.readLocalNote(userId, noteId);
    if (note == null) {
      throw StateError('Note $noteId was not found for task $taskId.');
    }
    final identity = note.taskIdentities.where((item) => item.id == taskId);
    if (identity.isEmpty) {
      throw StateError('Task $taskId is no longer attached to note $noteId.');
    }

    final lineIndex = identity.first.lineIndex;
    final tasks = TaskParser.extractTasks(
      note.content,
      identities: note.taskIdentities,
    );
    final matching = tasks.where((task) => task.id == taskId);
    if (matching.isEmpty || matching.first.lineIndex != lineIndex) {
      throw StateError(
        'Task $taskId changed before completion could be updated.',
      );
    }
    if (matching.first.isCompleted == isCompleted) {
      return;
    }

    final updatedContent = TaskParser.setTaskCompletion(
      note.content,
      lineIndex,
      isCompleted,
    );
    if (updatedContent == note.content) {
      throw StateError('Task $taskId could not be updated safely.');
    }
    await _notesService.updateNote(note.copyWith(content: updatedContent));
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
