enum CaptureDraftKind { task, taskList, project }

class CaptureDraft {
  const CaptureDraft({
    required this.kind,
    required this.rawText,
    required this.tasks,
    this.projectName,
    this.deadline,
  });

  final CaptureDraftKind kind;
  final String rawText;
  final List<String> tasks;
  final String? projectName;
  final DateTime? deadline;

  bool get createsProject => kind == CaptureDraftKind.project;

  String get primaryLabel {
    if (createsProject) {
      return projectName ?? 'New project';
    }
    if (tasks.length == 1) {
      return tasks.single;
    }
    return '${tasks.length} captured tasks';
  }
}

class CaptureResult {
  const CaptureResult({this.projectId, this.noteId, required this.taskCount});

  final String? projectId;
  final String? noteId;
  final int taskCount;
}
