import '../../projects/data/projects_repository.dart';
import '../../projects/models/project.dart';
import '../../tasks/data/task_service.dart';
import '../../tasks/models/task_metadata_update.dart';

/// Coordinates planning changes that span Tasks and Projects.
///
/// The Notes surface remains the source of truth for note-backed tasks. Project
/// deletion therefore clears task references first, then stages the Project
/// deletion. If task cleanup fails, the Project is left intact.
class PlanningService {
  PlanningService(this._taskService, this._projectsRepository);

  final TaskService _taskService;
  final ProjectsRepository _projectsRepository;

  Future<void> updateTaskMetadata({
    required String userId,
    required String noteId,
    required String taskId,
    required TaskMetadataUpdate update,
  }) {
    return _taskService.updateMetadata(
      userId: userId,
      noteId: noteId,
      taskId: taskId,
      update: update,
    );
  }

  Future<void> updateProject(Project project) {
    return _projectsRepository.updateProject(project);
  }

  /// Deletes a Project only after all locally known note-backed Tasks have been
  /// unassigned from it.
  ///
  /// This ordering intentionally prefers a harmless surviving Project over a
  /// deleted Project with dangling task metadata if local task cleanup fails.
  Future<int> deleteProjectAndUnassignTasks({
    required String userId,
    required String projectId,
  }) async {
    final clearedCount = await _taskService.clearProjectAssignments(
      userId: userId,
      projectId: projectId,
    );
    await _projectsRepository.deleteProject(userId, projectId);
    return clearedCount;
  }
}
