import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_project_store.dart';
import '../../../core/services/connectivity_providers.dart';
import '../../../core/services/firebase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/offline_first_projects_repository.dart';
import '../data/projects_repository.dart';
import '../models/project.dart';

final offlineProjectStoreProvider = Provider<OfflineProjectStore>((ref) {
  final store = OfflineProjectStore();
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final offlineStore = ref.watch(offlineProjectStoreProvider);
  final repository = OfflineFirstProjectsRepository(firestore, offlineStore);
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final projectsSyncProvider = Provider<void>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  final online = ref.watch(isOnlineProvider).asData?.value ?? false;
  final repository = ref.watch(projectsRepositoryProvider);

  if (user != null && online && repository is OfflineFirstProjectsRepository) {
    unawaited(repository.synchronize(user.uid));
  }
});

final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  ref.watch(projectsSyncProvider);

  final authState = ref.watch(authStateChangesProvider);
  final repository = ref.watch(projectsRepositoryProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <Project>[]);
      }
      return repository.watchProjects(user.uid);
    },
    loading: () => Stream.value(const <Project>[]),
    error: (_, _) => Stream.value(const <Project>[]),
  );
});

final activeProjectsProvider = Provider<List<Project>>((ref) {
  final projects =
      ref.watch(projectsStreamProvider).asData?.value ?? const <Project>[];
  return projects.where((project) => project.isActive).toList(growable: false);
});

final projectByIdProvider = Provider.family<Project?, String>((ref, projectId) {
  final projects =
      ref.watch(projectsStreamProvider).asData?.value ?? const <Project>[];
  for (final project in projects) {
    if (project.id == projectId) {
      return project;
    }
  }
  return null;
});
