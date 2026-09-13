import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/models/note.dart';
import '../../notes/providers/notes_providers.dart';
import '../data/task_projector.dart';
import '../data/task_service.dart';
import '../models/task.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.watch(notesServiceProvider));
});

final tasksProvider = Provider<List<Task>>((ref) {
  final notes = ref.watch(notesStreamProvider).asData?.value ?? const <Note>[];
  return TaskProjector.fromNotes(notes);
});

final taskByIdProvider = Provider.family<Task?, String>((ref, taskId) {
  for (final task in ref.watch(tasksProvider)) {
    if (task.id == taskId) {
      return task;
    }
  }
  return null;
});

final tasksForProjectProvider = Provider.family<List<Task>, String>((
  ref,
  projectId,
) {
  return ref
      .watch(tasksProvider)
      .where((task) => task.projectId == projectId)
      .toList(growable: false);
});

final unassignedTasksProvider = Provider<List<Task>>((ref) {
  return ref
      .watch(tasksProvider)
      .where((task) => task.projectId == null)
      .toList(growable: false);
});
