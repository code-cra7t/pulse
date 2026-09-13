import '../models/project.dart';

/// Persistence contract for Projects.
///
/// Patch 02 intentionally defines this boundary without choosing an online-only
/// implementation. The concrete repository should remain offline-first before
/// any Projects UI is exposed.
abstract interface class ProjectsRepository {
  Stream<List<Project>> watchProjects(String userId);

  Future<Project?> readProject(String userId, String projectId);

  Future<Project> createProject({
    required String userId,
    required String name,
    String description = '',
  });

  Future<void> updateProject(Project project);

  Future<void> deleteProject(String userId, String projectId);
}
