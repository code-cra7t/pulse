import 'task.dart';

enum TaskActionState { completed, ready, blocked }

enum TaskBlockerKind { prerequisite, waitingFor, missingDependency, cycle }

class TaskBlocker {
  const TaskBlocker({required this.kind, required this.label, this.taskId});

  final TaskBlockerKind kind;
  final String label;
  final String? taskId;
}

class TaskActionCue {
  const TaskActionCue({
    required this.task,
    required this.state,
    this.blockers = const <TaskBlocker>[],
  });

  final Task task;
  final TaskActionState state;
  final List<TaskBlocker> blockers;

  bool get isReady => state == TaskActionState.ready;
  bool get isBlocked => state == TaskActionState.blocked;

  String get shortLabel {
    if (state == TaskActionState.completed) return 'Completed';
    if (state == TaskActionState.ready) return 'Ready';
    if (blockers.isEmpty) return 'Blocked';
    final first = blockers.first;
    return switch (first.kind) {
      TaskBlockerKind.waitingFor => 'Waiting for ${first.label}',
      TaskBlockerKind.prerequisite => 'Blocked by ${first.label}',
      TaskBlockerKind.missingDependency => 'Missing dependency',
      TaskBlockerKind.cycle => 'Dependency cycle',
    };
  }
}

class ProjectActionCue {
  const ProjectActionCue({
    required this.projectId,
    required this.openCount,
    required this.blockedCount,
    this.nextTask,
  });

  final String projectId;
  final int openCount;
  final int blockedCount;
  final Task? nextTask;
}

class TaskDependencyAnalysis {
  const TaskDependencyAnalysis({
    required this.taskCues,
    required this.projectCues,
    this.cycleTaskIds = const <String>{},
  });

  final Map<String, TaskActionCue> taskCues;
  final Map<String, ProjectActionCue> projectCues;
  final Set<String> cycleTaskIds;

  TaskActionCue? cueForTask(String taskId) => taskCues[taskId];

  ProjectActionCue? cueForProject(String projectId) => projectCues[projectId];

  List<Task> get actionableTasks => taskCues.values
      .where((cue) => cue.state == TaskActionState.ready)
      .map((cue) => cue.task)
      .toList(growable: false);
}
