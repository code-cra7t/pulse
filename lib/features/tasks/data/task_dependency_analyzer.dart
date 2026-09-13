import '../../../core/models/priority_level.dart';
import '../models/task.dart';
import '../models/task_action_cue.dart';

class TaskDependencyAnalyzer {
  const TaskDependencyAnalyzer();

  TaskDependencyAnalysis analyze(List<Task> tasks) {
    final taskById = <String, Task>{for (final task in tasks) task.id: task};
    final cycles = _cycleTaskIds(tasks, taskById);
    final cues = <String, TaskActionCue>{};

    for (final task in tasks) {
      if (task.isCompleted) {
        cues[task.id] = TaskActionCue(
          task: task,
          state: TaskActionState.completed,
        );
        continue;
      }

      final blockers = <TaskBlocker>[];
      final waitingFor = task.waitingFor?.trim();
      if (waitingFor != null && waitingFor.isNotEmpty) {
        blockers.add(
          TaskBlocker(kind: TaskBlockerKind.waitingFor, label: waitingFor),
        );
      }
      if (cycles.contains(task.id)) {
        blockers.add(
          const TaskBlocker(
            kind: TaskBlockerKind.cycle,
            label: 'Dependency cycle',
          ),
        );
      }

      for (final dependencyId in task.dependsOnTaskIds) {
        final dependency = taskById[dependencyId];
        if (dependency == null) {
          blockers.add(
            TaskBlocker(
              kind: TaskBlockerKind.missingDependency,
              taskId: dependencyId,
              label: dependencyId,
            ),
          );
          continue;
        }
        if (!dependency.isCompleted) {
          blockers.add(
            TaskBlocker(
              kind: TaskBlockerKind.prerequisite,
              taskId: dependency.id,
              label: dependency.title,
            ),
          );
        }
      }

      cues[task.id] = TaskActionCue(
        task: task,
        state: blockers.isEmpty
            ? TaskActionState.ready
            : TaskActionState.blocked,
        blockers: List.unmodifiable(blockers),
      );
    }

    final projectIds = tasks
        .map((task) => task.projectId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final projectCues = <String, ProjectActionCue>{};
    for (final projectId in projectIds) {
      final projectTasks = tasks
          .where((task) => task.projectId == projectId && !task.isCompleted)
          .toList(growable: false);
      final ready =
          projectTasks.where((task) => cues[task.id]?.isReady == true).toList()
            ..sort(_compareNextActions);
      final blocked = projectTasks
          .where((task) => cues[task.id]?.isBlocked == true)
          .length;
      projectCues[projectId] = ProjectActionCue(
        projectId: projectId,
        openCount: projectTasks.length,
        blockedCount: blocked,
        nextTask: ready.isEmpty ? null : ready.first,
      );
    }

    return TaskDependencyAnalysis(
      taskCues: Map.unmodifiable(cues),
      projectCues: Map.unmodifiable(projectCues),
      cycleTaskIds: Set.unmodifiable(cycles),
    );
  }

  Set<String> _cycleTaskIds(List<Task> tasks, Map<String, Task> taskById) {
    final colors = <String, int>{};
    final stack = <String>[];
    final stackIndex = <String, int>{};
    final cycleIds = <String>{};

    void visit(String taskId) {
      final color = colors[taskId] ?? 0;
      if (color == 2) return;
      if (color == 1) {
        final start = stackIndex[taskId];
        if (start != null) cycleIds.addAll(stack.skip(start));
        return;
      }

      colors[taskId] = 1;
      stackIndex[taskId] = stack.length;
      stack.add(taskId);
      final task = taskById[taskId];
      if (task != null) {
        for (final dependencyId in task.dependsOnTaskIds) {
          if (taskById.containsKey(dependencyId)) visit(dependencyId);
        }
      }
      stack.removeLast();
      stackIndex.remove(taskId);
      colors[taskId] = 2;
    }

    for (final task in tasks) {
      if ((colors[task.id] ?? 0) == 0) visit(task.id);
    }
    return cycleIds;
  }

  static int _compareNextActions(Task a, Task b) {
    final aDue = a.dueAt;
    final bDue = b.dueAt;
    if (aDue != null && bDue != null) {
      final dueComparison = aDue.compareTo(bDue);
      if (dueComparison != 0) return dueComparison;
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }

    final priorityComparison = _priorityRank(
      b.priority,
    ).compareTo(_priorityRank(a.priority));
    if (priorityComparison != 0) return priorityComparison;

    final noteComparison = a.sourceNoteId.compareTo(b.sourceNoteId);
    if (noteComparison != 0) return noteComparison;
    final lineComparison = a.sourceLineIndex.compareTo(b.sourceLineIndex);
    if (lineComparison != 0) return lineComparison;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static int _priorityRank(PriorityLevel priority) => switch (priority) {
    PriorityLevel.none => 0,
    PriorityLevel.low => 1,
    PriorityLevel.medium => 2,
    PriorityLevel.high => 3,
    PriorityLevel.critical => 4,
  };
}
