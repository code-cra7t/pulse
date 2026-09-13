import '../../notes/data/notes_service.dart';
import '../../notes/models/note.dart';
import '../../projects/data/projects_repository.dart';
import '../../projects/models/project.dart';
import '../../tasks/data/task_metadata_editor.dart';
import '../../tasks/models/task_metadata_update.dart';
import '../models/capture_draft.dart';

class CaptureService {
  CaptureService(this._notesService, this._projectsRepository);

  final NotesService _notesService;
  final ProjectsRepository _projectsRepository;

  static const int _captureNoteColor = 0xFFFFF8E1;

  Future<CaptureResult> createStructured({
    required String userId,
    required CaptureDraft draft,
  }) async {
    if (draft.tasks.isEmpty && !draft.createsProject) {
      throw ArgumentError('A structured capture requires at least one task.');
    }

    Project? project;
    Note? note;
    try {
      if (draft.createsProject) {
        final name = draft.projectName?.trim() ?? '';
        if (name.isEmpty) {
          throw ArgumentError('A project capture requires a project name.');
        }
        final createdProject = await _projectsRepository.createProject(
          userId: userId,
          name: name,
        );
        project = createdProject;
        if (draft.deadline != null) {
          final updatedProject = createdProject.copyWith(
            deadline: draft.deadline,
          );
          await _projectsRepository.updateProject(updatedProject);
          project = updatedProject;
        }
      }

      if (draft.tasks.isNotEmpty) {
        note = await _notesService.createNote(
          userId: userId,
          title: project?.name ?? _taskNoteTitle(draft.tasks),
          content: draft.tasks.map((task) => '- $task').join('\n'),
          color: _captureNoteColor,
          tags: project == null
              ? const ['Captured']
              : const ['Captured', 'Plan'],
        );

        if (note.taskIdentities.isNotEmpty &&
            (project != null || draft.deadline != null)) {
          var enriched = note;
          for (final identity in note.taskIdentities) {
            enriched = TaskMetadataEditor.apply(
              note: enriched,
              taskId: identity.id,
              update: TaskMetadataUpdate(
                projectId: project?.id,
                dueAt: draft.deadline,
              ),
            );
          }
          await _notesService.updateNote(enriched);
        }
      }

      return CaptureResult(
        projectId: project?.id,
        noteId: note?.id,
        taskCount: draft.tasks.length,
      );
    } catch (_) {
      if (note != null) {
        await _bestEffortDeleteNote(note);
      }
      if (project != null) {
        await _bestEffortDeleteProject(project);
      }
      rethrow;
    }
  }

  Future<CaptureResult> saveAsNote({
    required String userId,
    required String rawText,
  }) async {
    final content = rawText.trim();
    if (content.isEmpty) {
      throw ArgumentError('Capture text cannot be empty.');
    }
    final note = await _notesService.createNote(
      userId: userId,
      title: _rawNoteTitle(content),
      content: content,
      color: _captureNoteColor,
      tags: const ['Captured'],
    );
    return CaptureResult(noteId: note.id, taskCount: 0);
  }

  Future<void> _bestEffortDeleteNote(Note note) async {
    try {
      await _notesService.deleteNote(note.id, userId: note.userId);
    } catch (_) {
      // Preserve the original capture error. Offline cleanup can be retried by
      // the normal sync path if the delete was staged successfully.
    }
  }

  Future<void> _bestEffortDeleteProject(Project project) async {
    try {
      await _projectsRepository.deleteProject(project.userId, project.id);
    } catch (_) {
      // Preserve the original capture error.
    }
  }

  String _taskNoteTitle(List<String> tasks) {
    if (tasks.length == 1) {
      return _truncate(tasks.single, 72);
    }
    return 'Captured tasks';
  }

  String _rawNoteTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    return _truncate(firstLine.isEmpty ? 'Quick capture' : firstLine, 72);
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1).trimRight()}…';
  }
}
