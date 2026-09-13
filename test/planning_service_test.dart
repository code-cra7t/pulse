import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/planning/data/planning_service.dart';
import 'package:pulse/features/projects/data/projects_repository.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/tasks/data/task_service.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  test(
    'project deletion clears task references before deleting project',
    () async {
      final calls = <String>[];
      final taskService = _FakeTaskService(calls: calls, clearedCount: 3);
      final projectsRepository = _FakeProjectsRepository(calls);
      final service = PlanningService(taskService, projectsRepository);

      final cleared = await service.deleteProjectAndUnassignTasks(
        userId: 'user-1',
        projectId: 'project-1',
      );

      expect(cleared, 3);
      expect(calls, ['clear:project-1', 'delete:project-1']);
    },
  );

  test('project deletion stops when task cleanup fails', () async {
    final calls = <String>[];
    final taskService = _FakeTaskService(calls: calls, failCleanup: true);
    final projectsRepository = _FakeProjectsRepository(calls);
    final service = PlanningService(taskService, projectsRepository);

    await expectLater(
      service.deleteProjectAndUnassignTasks(
        userId: 'user-1',
        projectId: 'project-1',
      ),
      throwsStateError,
    );

    expect(calls, ['clear:project-1']);
  });

  test(
    'task metadata updates are delegated to the note-backed task service',
    () async {
      final calls = <String>[];
      final taskService = _FakeTaskService(calls: calls);
      final service = PlanningService(
        taskService,
        _FakeProjectsRepository(calls),
      );

      await service.updateTaskMetadata(
        userId: 'user-1',
        noteId: 'note-1',
        taskId: 'task-1',
        update: const TaskMetadataUpdate(projectId: 'project-1'),
      );

      expect(calls, ['update:task-1']);
    },
  );
}

class _FakeTaskService implements TaskService {
  _FakeTaskService({
    required this.calls,
    this.clearedCount = 0,
    this.failCleanup = false,
  });

  final List<String> calls;
  final int clearedCount;
  final bool failCleanup;

  @override
  Future<int> clearProjectAssignments({
    required String userId,
    required String projectId,
  }) async {
    calls.add('clear:$projectId');
    if (failCleanup) {
      throw StateError('cleanup failed');
    }
    return clearedCount;
  }

  @override
  Future<void> updateMetadata({
    required String userId,
    required String noteId,
    required String taskId,
    required TaskMetadataUpdate update,
  }) async {
    calls.add('update:$taskId');
  }
}

class _FakeProjectsRepository implements ProjectsRepository {
  _FakeProjectsRepository(this.calls);

  final List<String> calls;

  @override
  Future<Project> createProject({
    required String userId,
    required String name,
    String description = '',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProject(String userId, String projectId) async {
    calls.add('delete:$projectId');
  }

  @override
  Future<Project?> readProject(String userId, String projectId) async => null;

  @override
  Future<void> updateProject(Project project) async {
    calls.add('project-update:${project.id}');
  }

  @override
  Stream<List<Project>> watchProjects(String userId) {
    return Stream.value(const <Project>[]);
  }
}
