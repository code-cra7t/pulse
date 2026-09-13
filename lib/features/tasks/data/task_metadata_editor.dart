import '../../notes/models/note.dart';
import '../models/note_task_identity.dart';
import '../models/task_metadata_update.dart';

class TaskMetadataEditor {
  const TaskMetadataEditor._();

  static Note apply({
    required Note note,
    required String taskId,
    required TaskMetadataUpdate update,
  }) {
    update.validate();
    final index = note.taskIdentities.indexWhere(
      (identity) => identity.id == taskId,
    );
    if (index < 0) {
      throw StateError('Task $taskId is not attached to note ${note.id}.');
    }

    final current = note.taskIdentities[index];
    final next = _applyUpdate(current, update);
    final identities = <NoteTaskIdentity>[...note.taskIdentities];
    identities[index] = next;
    return note.copyWith(taskIdentities: identities);
  }

  static Note clearProjectAssignments({
    required Note note,
    required String projectId,
  }) {
    var changed = false;
    final identities = note.taskIdentities
        .map((identity) {
          if (identity.projectId != projectId) {
            return identity;
          }
          changed = true;
          return identity.copyWith(projectId: null);
        })
        .toList(growable: false);
    return changed ? note.copyWith(taskIdentities: identities) : note;
  }

  static NoteTaskIdentity _applyUpdate(
    NoteTaskIdentity identity,
    TaskMetadataUpdate update,
  ) {
    var next = identity;

    if (update.clearProjectId) {
      next = next.copyWith(projectId: null);
    } else if (update.projectId != null) {
      final normalized = update.projectId!.trim();
      next = next.copyWith(projectId: normalized.isEmpty ? null : normalized);
    }

    if (update.clearDueAt) {
      next = next.copyWith(dueAt: null);
    } else if (update.dueAt != null) {
      next = next.copyWith(dueAt: update.dueAt);
    }

    if (update.priority != null) {
      next = next.copyWith(priority: update.priority);
    }

    if (update.clearEstimatedMinutes) {
      next = next.copyWith(estimatedMinutes: null);
    } else if (update.estimatedMinutes != null) {
      next = next.copyWith(estimatedMinutes: update.estimatedMinutes);
    }

    if (update.isFlexible != null) {
      next = next.copyWith(isFlexible: update.isFlexible);
    }

    return next;
  }
}
