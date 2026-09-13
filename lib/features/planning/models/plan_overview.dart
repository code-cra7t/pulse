import '../../projects/models/project.dart';
import '../../tasks/models/task.dart';

class PlanOverview {
  const PlanOverview({
    required this.projects,
    required this.openTasks,
    required this.overdueTasks,
    required this.dueSoonTasks,
    required this.unassignedTasks,
    required this.totalTasksByProjectId,
    required this.completedTasksByProjectId,
  });

  final List<Project> projects;
  final List<Task> openTasks;
  final List<Task> overdueTasks;
  final List<Task> dueSoonTasks;
  final List<Task> unassignedTasks;
  final Map<String, int> totalTasksByProjectId;
  final Map<String, int> completedTasksByProjectId;

  int get activeProjectCount =>
      projects.where((project) => project.isActive).length;

  int totalTasksForProject(String projectId) =>
      totalTasksByProjectId[projectId] ?? 0;

  int completedTasksForProject(String projectId) =>
      completedTasksByProjectId[projectId] ?? 0;

  double progressForProject(String projectId) {
    final total = totalTasksForProject(projectId);
    if (total == 0) {
      return 0;
    }
    return completedTasksForProject(projectId) / total;
  }

  factory PlanOverview.build({
    required List<Project> projects,
    required List<Task> tasks,
    required DateTime now,
  }) {
    final sortedProjects = [...projects]..sort(_compareProjects);
    final openTasks = tasks.where((task) => !task.isCompleted).toList()
      ..sort((a, b) => _compareTasks(a, b, now));

    final startOfToday = DateTime(now.year, now.month, now.day);
    final dueSoonCutoff = startOfToday.add(const Duration(days: 7));
    final overdueTasks = openTasks
        .where((task) {
          final dueAt = task.dueAt;
          return dueAt != null && dueAt.isBefore(now);
        })
        .toList(growable: false);
    final dueSoonTasks = openTasks
        .where((task) {
          final dueAt = task.dueAt;
          return dueAt != null &&
              !dueAt.isBefore(startOfToday) &&
              dueAt.isBefore(dueSoonCutoff);
        })
        .toList(growable: false);
    final knownProjectIds = projects.map((project) => project.id).toSet();
    final unassignedTasks = openTasks
        .where((task) {
          final projectId = task.projectId;
          return projectId == null || !knownProjectIds.contains(projectId);
        })
        .toList(growable: false);

    final totalByProject = <String, int>{};
    final completedByProject = <String, int>{};
    for (final task in tasks) {
      final projectId = task.projectId;
      if (projectId == null) {
        continue;
      }
      totalByProject.update(projectId, (value) => value + 1, ifAbsent: () => 1);
      if (task.isCompleted) {
        completedByProject.update(
          projectId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return PlanOverview(
      projects: List.unmodifiable(sortedProjects),
      openTasks: List.unmodifiable(openTasks),
      overdueTasks: List.unmodifiable(overdueTasks),
      dueSoonTasks: List.unmodifiable(dueSoonTasks),
      unassignedTasks: List.unmodifiable(unassignedTasks),
      totalTasksByProjectId: Map.unmodifiable(totalByProject),
      completedTasksByProjectId: Map.unmodifiable(completedByProject),
    );
  }

  static int _compareProjects(Project a, Project b) {
    final statusComparison = _statusRank(
      a.status,
    ).compareTo(_statusRank(b.status));
    if (statusComparison != 0) {
      return statusComparison;
    }

    final aDeadline = a.deadline;
    final bDeadline = b.deadline;
    if (aDeadline != null && bDeadline != null) {
      final deadlineComparison = aDeadline.compareTo(bDeadline);
      if (deadlineComparison != 0) {
        return deadlineComparison;
      }
    } else if (aDeadline != null) {
      return -1;
    } else if (bDeadline != null) {
      return 1;
    }

    return b.updatedAt.compareTo(a.updatedAt);
  }

  static int _compareTasks(Task a, Task b, DateTime now) {
    final aOverdue = a.dueAt?.isBefore(now) ?? false;
    final bOverdue = b.dueAt?.isBefore(now) ?? false;
    if (aOverdue != bOverdue) {
      return aOverdue ? -1 : 1;
    }

    final aDue = a.dueAt;
    final bDue = b.dueAt;
    if (aDue != null && bDue != null) {
      final dueComparison = aDue.compareTo(bDue);
      if (dueComparison != 0) {
        return dueComparison;
      }
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }

    final priorityComparison = b.priority.index.compareTo(a.priority.index);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static int _statusRank(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => 0,
      ProjectStatus.paused => 1,
      ProjectStatus.completed => 2,
      ProjectStatus.archived => 3,
    };
  }
}
