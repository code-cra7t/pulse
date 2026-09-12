import '../../notes/models/note_task.dart';
import '../models/note_task_identity.dart';

/// Reconciles parsed note tasks with their previously persisted identities.
///
/// The note body remains the source of truth for task text and completion. This
/// metadata exists only to give a task a durable identity while preserving the
/// current Notes editor and plain-text storage format.
class TaskIdentityReconciler {
  const TaskIdentityReconciler._();

  static List<NoteTaskIdentity> reconcile({
    required List<NoteTask> currentTasks,
    required List<NoteTaskIdentity> previousIdentities,
    required String Function() createId,
  }) {
    if (currentTasks.isEmpty) {
      return const <NoteTaskIdentity>[];
    }

    final available = <NoteTaskIdentity>[...previousIdentities]
      ..removeWhere((identity) => identity.id.trim().isEmpty);
    final matches = List<NoteTaskIdentity?>.filled(currentTasks.length, null);

    // Pass 1: the task is unchanged and still on the same line.
    for (var index = 0; index < currentTasks.length; index++) {
      final task = currentTasks[index];
      final matchIndex = available.indexWhere(
        (identity) =>
            identity.lineIndex == task.lineIndex &&
            identity.matchesText(task.text),
      );
      if (matchIndex >= 0) {
        matches[index] = available.removeAt(matchIndex);
      }
    }

    // Pass 2: preserve identity when surrounding lines/tasks moved. Doing this
    // before same-line fallback prevents a newly inserted task from stealing
    // the ID of an older task that shifted down.
    for (var index = 0; index < currentTasks.length; index++) {
      if (matches[index] != null) {
        continue;
      }
      final task = currentTasks[index];
      final normalizedText = normalizeTaskIdentityText(task.text);
      var nearestTextIndex = -1;
      var nearestDistance = 1 << 30;

      for (
        var candidateIndex = 0;
        candidateIndex < available.length;
        candidateIndex++
      ) {
        final identity = available[candidateIndex];
        if (identity.normalizedText != normalizedText) {
          continue;
        }
        final distance = (identity.lineIndex - task.lineIndex).abs();
        if (distance < nearestDistance) {
          nearestTextIndex = candidateIndex;
          nearestDistance = distance;
        }
      }

      if (nearestTextIndex >= 0) {
        matches[index] = available.removeAt(nearestTextIndex);
      }
    }

    // Pass 3: if text was edited in place, keep the identity on that line.
    for (var index = 0; index < currentTasks.length; index++) {
      if (matches[index] != null) {
        continue;
      }
      final task = currentTasks[index];
      final sameLineIndex = available.indexWhere(
        (identity) => identity.lineIndex == task.lineIndex,
      );
      if (sameLineIndex >= 0) {
        matches[index] = available.removeAt(sameLineIndex);
      }
    }

    return [
      for (var index = 0; index < currentTasks.length; index++)
        matches[index]?.copyWith(
              lineIndex: currentTasks[index].lineIndex,
              text: currentTasks[index].text,
            ) ??
            NoteTaskIdentity(
              id: createId(),
              lineIndex: currentTasks[index].lineIndex,
              text: currentTasks[index].text,
            ),
    ];
  }
}
