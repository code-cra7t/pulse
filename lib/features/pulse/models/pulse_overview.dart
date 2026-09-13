import '../../../core/models/priority_level.dart';
import '../../projects/models/project.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_action_cue.dart';

enum PulseCueKind { overdue, deadline, unplanned }

class PulseCue {
  const PulseCue({
    required this.kind,
    required this.title,
    required this.message,
  });

  final PulseCueKind kind;
  final String title;
  final String message;
}

class PulseFocusItem {
  const PulseFocusItem({
    required this.task,
    required this.reason,
    this.project,
  });

  final Task task;
  final Project? project;
  final String reason;
}

class PulseOverview {
  const PulseOverview({
    required this.focusItems,
    required this.cues,
    required this.upcomingProjects,
    required this.openTaskCount,
    required this.overdueCount,
    required this.dueTodayCount,
    required this.focusEstimatedMinutes,
  });

  final List<PulseFocusItem> focusItems;
  final List<PulseCue> cues;
  final List<Project> upcomingProjects;
  final int openTaskCount;
  final int overdueCount;
  final int dueTodayCount;
  final int focusEstimatedMinutes;

  factory PulseOverview.build({
    required List<Project> projects,
    required List<Task> tasks,
    required DateTime now,
    TaskDependencyAnalysis? dependencyAnalysis,
    int focusLimit = 3,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final projectById = <String, Project>{
      for (final project in projects) project.id: project,
    };
    final openTasks = tasks.where((task) => !task.isCompleted).toList();
    final focusCandidates = dependencyAnalysis == null
        ? [...openTasks]
        : openTasks
              .where(
                (task) =>
                    dependencyAnalysis.cueForTask(task.id)?.isBlocked != true,
              )
              .toList();

    openTasks.sort(
      (a, b) =>
          _compareTasks(a, b, now: now, today: today, projectById: projectById),
    );

    focusCandidates.sort(
      (a, b) =>
          _compareTasks(a, b, now: now, today: today, projectById: projectById),
    );
    final focusTasks = focusCandidates.take(focusLimit).toList(growable: false);
    final focusItems = focusTasks
        .map(
          (task) => PulseFocusItem(
            task: task,
            project: task.projectId == null
                ? null
                : projectById[task.projectId!],
            reason: _focusReason(
              task,
              now: now,
              today: today,
              project: task.projectId == null
                  ? null
                  : projectById[task.projectId!],
            ),
          ),
        )
        .toList(growable: false);

    final overdue = openTasks.where((task) {
      final dueAt = task.dueAt;
      return dueAt != null && dueAt.isBefore(now);
    }).length;
    final dueToday = openTasks.where((task) {
      final dueAt = task.dueAt;
      return dueAt != null &&
          !dueAt.isBefore(today) &&
          dueAt.isBefore(tomorrow);
    }).length;

    final activeProjects = projects.where((project) => project.isActive);
    final deadlineCutoff = today.add(const Duration(days: 14));
    final upcomingProjects = activeProjects.where((project) {
      final deadline = project.deadline;
      return deadline != null &&
          !deadline.isBefore(today) &&
          deadline.isBefore(deadlineCutoff);
    }).toList()..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    final cues = <PulseCue>[];
    if (overdue > 0) {
      cues.add(
        PulseCue(
          kind: PulseCueKind.overdue,
          title: overdue == 1 ? '1 overdue task' : '$overdue overdue tasks',
          message:
              'Clear or reschedule overdue work before it keeps piling up.',
        ),
      );
    }

    final projectDeadlinesThisWeek = activeProjects.where((project) {
      final deadline = project.deadline;
      if (deadline == null || deadline.isBefore(today)) {
        return false;
      }
      return deadline.isBefore(today.add(const Duration(days: 7)));
    }).length;
    if (projectDeadlinesThisWeek > 0) {
      cues.add(
        PulseCue(
          kind: PulseCueKind.deadline,
          title: projectDeadlinesThisWeek == 1
              ? '1 project deadline this week'
              : '$projectDeadlinesThisWeek project deadlines this week',
          message: 'Make sure the work behind those deadlines has enough room.',
        ),
      );
    }

    final unplannedHighPriority = openTasks.where((task) {
      return task.dueAt == null &&
          (task.priority == PriorityLevel.high ||
              task.priority == PriorityLevel.critical);
    }).length;
    if (unplannedHighPriority > 0) {
      cues.add(
        PulseCue(
          kind: PulseCueKind.unplanned,
          title: unplannedHighPriority == 1
              ? '1 high-priority task has no date'
              : '$unplannedHighPriority high-priority tasks have no date',
          message:
              'Give important undated work a deadline or keep it flexible on purpose.',
        ),
      );
    }

    return PulseOverview(
      focusItems: List.unmodifiable(focusItems),
      cues: List.unmodifiable(cues),
      upcomingProjects: List.unmodifiable(upcomingProjects.take(3)),
      openTaskCount: openTasks.length,
      overdueCount: overdue,
      dueTodayCount: dueToday,
      focusEstimatedMinutes: focusTasks.fold<int>(
        0,
        (sum, task) => sum + (task.estimatedMinutes ?? 0),
      ),
    );
  }

  static int _compareTasks(
    Task a,
    Task b, {
    required DateTime now,
    required DateTime today,
    required Map<String, Project> projectById,
  }) {
    final aScore = _focusScore(
      a,
      now: now,
      today: today,
      project: a.projectId == null ? null : projectById[a.projectId!],
    );
    final bScore = _focusScore(
      b,
      now: now,
      today: today,
      project: b.projectId == null ? null : projectById[b.projectId!],
    );
    final scoreComparison = bScore.compareTo(aScore);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final aDue = a.dueAt;
    final bDue = b.dueAt;
    if (aDue != null && bDue != null) {
      final comparison = aDue.compareTo(bDue);
      if (comparison != 0) {
        return comparison;
      }
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static int _focusScore(
    Task task, {
    required DateTime now,
    required DateTime today,
    required Project? project,
  }) {
    var score = switch (task.priority) {
      PriorityLevel.critical => 360,
      PriorityLevel.high => 250,
      PriorityLevel.medium => 140,
      PriorityLevel.low => 50,
      PriorityLevel.none => 0,
    };

    final dueAt = task.dueAt;
    if (dueAt != null) {
      if (dueAt.isBefore(now)) {
        final rawOverdueDays = now.difference(dueAt).inDays;
        final overdueDays = rawOverdueDays < 0
            ? 0
            : rawOverdueDays > 30
            ? 30
            : rawOverdueDays;
        score += 2000 + overdueDays * 5;
      } else {
        final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
        final days = dueDay.difference(today).inDays;
        score += switch (days) {
          <= 0 => 900,
          1 => 800,
          2 => 720,
          3 => 660,
          <= 7 => 600 - (days * 20),
          <= 14 => 360 - (days * 8),
          _ => 120,
        };
      }
    }

    if (project != null && project.isActive) {
      score += switch (project.priority) {
        PriorityLevel.critical => 120,
        PriorityLevel.high => 80,
        PriorityLevel.medium => 45,
        PriorityLevel.low => 20,
        PriorityLevel.none => 0,
      };

      final deadline = project.deadline;
      if (deadline != null && !deadline.isBefore(today)) {
        final deadlineDay = DateTime(
          deadline.year,
          deadline.month,
          deadline.day,
        );
        final days = deadlineDay.difference(today).inDays;
        if (days <= 3) {
          score += 160;
        } else if (days <= 7) {
          score += 90;
        }
      }
    }

    return score;
  }

  static String _focusReason(
    Task task, {
    required DateTime now,
    required DateTime today,
    required Project? project,
  }) {
    final dueAt = task.dueAt;
    if (dueAt != null) {
      if (dueAt.isBefore(now)) {
        final days = now.difference(dueAt).inDays;
        return days <= 0
            ? 'Overdue'
            : 'Overdue by $days ${days == 1 ? 'day' : 'days'}';
      }
      final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
      final days = dueDay.difference(today).inDays;
      if (days <= 0) {
        return 'Due today';
      }
      if (days == 1) {
        return 'Due tomorrow';
      }
      if (days <= 7) {
        return 'Due in $days days';
      }
    }

    if (task.priority == PriorityLevel.critical) {
      return 'Critical priority';
    }
    if (task.priority == PriorityLevel.high) {
      return 'High priority';
    }

    final deadline = project?.deadline;
    if (deadline != null && !deadline.isBefore(today)) {
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      final days = deadlineDay.difference(today).inDays;
      if (days <= 0) {
        return 'Project deadline today';
      }
      if (days == 1) {
        return 'Project deadline tomorrow';
      }
      if (days <= 7) {
        return 'Project deadline in $days days';
      }
    }

    return project == null ? 'Open task' : project.name;
  }
}
