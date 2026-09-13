import '../../notes/models/note.dart';
import '../../notes/utils/task_parser.dart';
import 'task_identity_reconciler.dart';

/// Compatibility helpers for Note-backed Task metadata during app upgrades.
///
/// Visible Note content remains authoritative. When a mutation produced by an
/// older client is uploaded by a modern client, current Task lines are
/// reconciled against a modern remote identity list before the write receives
/// the current schema/token. This prevents an upgrade from legitimizing a
/// lossy legacy identity payload.
class TaskMetadataCompatibility {
  const TaskMetadataCompatibility._();

  static Note hardenLegacyMutation({
    required Note pendingNote,
    required Note? remoteNote,
    required String Function() createTaskId,
    required String writeToken,
  }) {
    if (pendingNote.usesModernTaskMetadata) return pendingNote;

    final normalizedContent = TaskParser.normalizeTaskContent(
      pendingNote.content,
    );
    final previousIdentities = remoteNote?.usesModernTaskMetadata == true
        ? remoteNote!.taskIdentities
        : pendingNote.taskIdentities;

    return pendingNote.copyWith(
      content: normalizedContent,
      taskIdentities: TaskIdentityReconciler.reconcile(
        currentTasks: TaskParser.extractTasks(normalizedContent),
        previousIdentities: previousIdentities,
        createId: createTaskId,
      ),
      taskMetadataSchemaVersion: _schemaForHardenedWrite(
        pendingNote,
        remoteNote,
      ),
      taskMetadataWriteToken: writeToken,
    );
  }
}

int _schemaForHardenedWrite(Note pendingNote, Note? remoteNote) {
  var schema = currentTaskMetadataSchemaVersion;
  if (pendingNote.taskMetadataSchemaVersion > schema) {
    schema = pendingNote.taskMetadataSchemaVersion;
  }
  final remoteSchema = remoteNote?.taskMetadataSchemaVersion ?? 0;
  if (remoteSchema > schema) schema = remoteSchema;
  return schema;
}
