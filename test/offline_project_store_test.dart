import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/core/offline/offline_project_store.dart';
import 'package:pulse/core/offline/pending_project_mutation.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineProjectStore store;

  setUp(() {
    final databaseName =
        'jotcue-project-test-${DateTime.now().microsecondsSinceEpoch}.db';
    store = OfflineProjectStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
    );
  });

  tearDown(() async {
    await store.dispose();
  });

  test(
    'stages project changes locally and collapses repeated mutations',
    () async {
      final project = _project(name: 'Insurance exam');
      await store.stageUpsert(project, _upsertMutation('mutation-1', project));

      expect(await store.readProjects(project.userId), [
        hasName('Insurance exam'),
      ]);
      expect(await store.pendingMutations(project.userId), hasLength(1));

      final updated = project.copyWith(
        name: 'Life insurance exam',
        updatedAt: project.updatedAt.add(const Duration(minutes: 1)),
      );
      await store.stageUpsert(updated, _upsertMutation('mutation-2', updated));

      final pending = await store.pendingMutations(project.userId);
      expect(await store.readProjects(project.userId), [
        hasName('Life insurance exam'),
      ]);
      expect(pending, hasLength(1));
      expect(pending.single.id, 'mutation-2');
    },
  );

  test(
    'round-trips project planning metadata through the offline store',
    () async {
      final project = _project(name: 'HPC').copyWith(
        description: 'Parallel Monte Carlo work',
        priority: PriorityLevel.critical,
        deadline: DateTime(2026, 9, 30),
        targetMinutesPerWeek: 420,
      );

      await store.stageUpsert(project, _upsertMutation('mutation-1', project));

      final stored = await store.readProject(project.userId, project.id);
      expect(stored, isNotNull);
      expect(stored!.description, 'Parallel Monte Carlo work');
      expect(stored.priority, PriorityLevel.critical);
      expect(stored.deadline, DateTime(2026, 9, 30));
      expect(stored.targetMinutesPerWeek, 420);
    },
  );

  test(
    'remote merge does not overwrite a pending local project edit',
    () async {
      final local = _project(name: 'Local name');
      await store.stageUpsert(local, _upsertMutation('mutation-1', local));

      final remote = local.copyWith(
        name: 'Remote name',
        updatedAt: local.updatedAt.add(const Duration(minutes: 1)),
      );
      await store.mergeRemoteProjects(local.userId, [remote]);

      expect(await store.readProjects(local.userId), [hasName('Local name')]);

      await store.removeMutation('mutation-1');
      await store.mergeRemoteProjects(local.userId, [remote]);

      expect(await store.readProjects(local.userId), [hasName('Remote name')]);
    },
  );

  test('pending offline delete stays deleted during remote merge', () async {
    final project = _project(name: 'Delete me');
    await store.stageUpsert(project, _upsertMutation('mutation-1', project));

    final deleteMutation = PendingProjectMutation(
      id: 'mutation-2',
      userId: project.userId,
      projectId: project.id,
      type: PendingProjectMutationType.delete,
      payload: null,
      createdAt: DateTime(2026, 9, 12, 12),
    );
    await store.stageDelete(project.userId, project.id, deleteMutation);
    await store.mergeRemoteProjects(project.userId, [project]);

    expect(await store.readProjects(project.userId), isEmpty);
    final pending = await store.pendingMutations(project.userId);
    expect(pending.single.type, PendingProjectMutationType.delete);
  });

  test(
    'projects are ordered active first and deadlines before undated work',
    () async {
      final base = _project(name: 'Undated active');
      final deadline = Project(
        id: 'project-2',
        userId: base.userId,
        name: 'Dated active',
        deadline: DateTime(2026, 9, 15),
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
      );
      final paused = Project(
        id: 'project-3',
        userId: base.userId,
        name: 'Paused',
        status: ProjectStatus.paused,
        deadline: DateTime(2026, 9, 13),
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
      );

      await store.stageUpsert(base, _upsertMutation('mutation-1', base));
      await store.stageUpsert(
        deadline,
        _upsertMutation('mutation-2', deadline),
      );
      await store.stageUpsert(paused, _upsertMutation('mutation-3', paused));

      final projects = await store.readProjects(base.userId);
      expect(projects.map((project) => project.name), [
        'Dated active',
        'Undated active',
        'Paused',
      ]);
    },
  );

  test('clears cached projects and mutations for only one user', () async {
    final first = _project(name: 'First user');
    final second = Project(
      id: 'project-2',
      userId: 'user-2',
      name: 'Second user',
      createdAt: DateTime(2026, 9, 12),
      updatedAt: DateTime(2026, 9, 12),
    );

    await store.stageUpsert(first, _upsertMutation('mutation-1', first));
    await store.stageUpsert(second, _upsertMutation('mutation-2', second));
    await store.clearUser(first.userId);

    expect(await store.readProjects(first.userId), isEmpty);
    expect(await store.pendingMutations(first.userId), isEmpty);
    expect(await store.readProjects(second.userId), hasLength(1));
    expect(await store.pendingMutations(second.userId), hasLength(1));
  });
}

Project _project({required String name}) {
  return Project(
    id: 'project-1',
    userId: 'user-1',
    name: name,
    createdAt: DateTime(2026, 9, 12, 10),
    updatedAt: DateTime(2026, 9, 12, 10),
  );
}

PendingProjectMutation _upsertMutation(String id, Project project) {
  return PendingProjectMutation(
    id: id,
    userId: project.userId,
    projectId: project.id,
    type: PendingProjectMutationType.upsert,
    payload: project.toLocalMap(),
    createdAt: project.updatedAt,
  );
}

Matcher hasName(String name) {
  return isA<Project>().having((project) => project.name, 'name', name);
}
