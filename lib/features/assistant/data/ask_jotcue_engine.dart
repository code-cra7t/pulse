import '../../../core/models/priority_level.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../models/ask_jotcue.dart';

/// Deterministic, read-only assistant over JotCue's existing planning state.
///
/// This intentionally does not call a network model and never mutates data.
class AskJotCueEngine {
  const AskJotCueEngine();

  AskJotCueAnswer answer({
    required String query,
    required AskJotCueContext context,
  }) {
    final intent = classify(query);
    return switch (intent) {
      AskJotCueIntent.focusNow => _focus(context),
      AskJotCueIntent.dueSoon => _dueSoon(context),
      AskJotCueIntent.overdue => _overdue(context),
      AskJotCueIntent.capacityToday => _capacity(context),
      AskJotCueIntent.scheduleToday => _schedule(context),
      AskJotCueIntent.nextBlock => _nextBlock(context),
      AskJotCueIntent.projects => _projects(context),
      AskJotCueIntent.needsAttention => _attention(context),
      AskJotCueIntent.help => _help(),
      AskJotCueIntent.unknown => _unknown(),
    };
  }

  AskJotCueIntent classify(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty ||
        _containsAny(normalized, const [
          'help',
          'what can you do',
          'what can i ask',
          'how can you help',
        ])) {
      return AskJotCueIntent.help;
    }

    if (_containsAny(normalized, const [
      'what should i do now',
      'what should i work on',
      'what should i focus',
      'what matters most',
      'my priorities',
      'priority right now',
      'focus now',
    ])) {
      return AskJotCueIntent.focusNow;
    }

    if (_containsAny(normalized, const [
      'overdue',
      'behind',
      'late task',
      'what am i late',
    ])) {
      return AskJotCueIntent.overdue;
    }

    if (_containsAny(normalized, const [
      'free time',
      'how much time',
      'capacity today',
      'available today',
      'time do i have',
    ])) {
      return AskJotCueIntent.capacityToday;
    }

    if (_containsAny(normalized, const [
      'what is next',
      "what's next",
      'next block',
      'next scheduled',
      'up next',
    ])) {
      return AskJotCueIntent.nextBlock;
    }

    if (_containsAny(normalized, const [
      'schedule today',
      "today's schedule",
      'today schedule',
      'planned today',
      'what is planned',
      "what's planned",
    ])) {
      return AskJotCueIntent.scheduleToday;
    }

    if (_containsAny(normalized, const [
      'due soon',
      'deadline',
      'due next',
      'coming up',
      'due this week',
    ])) {
      return AskJotCueIntent.dueSoon;
    }

    if (_containsAny(normalized, const [
      'needs attention',
      'need attention',
      'what am i forgetting',
      'what needs review',
      'problems with my plan',
      'schedule problems',
    ])) {
      return AskJotCueIntent.needsAttention;
    }

    if (_containsAny(normalized, const ['project', 'projects'])) {
      return AskJotCueIntent.projects;
    }

    return AskJotCueIntent.unknown;
  }

  AskJotCueAnswer _focus(AskJotCueContext context) {
    final items = context.pulse.focusItems;
    if (items.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.focusNow,
        title: 'Focus',
        text:
            'Nothing is strongly competing for attention right now. Add a deadline, priority, or project in Plan if you want JotCue to rank open work more precisely.',
      );
    }

    final lines = <String>[];
    for (var i = 0; i < items.length; i += 1) {
      final item = items[i];
      final effort = item.task.estimatedMinutes == null
          ? ''
          : ' · ${_formatMinutes(item.task.estimatedMinutes!)}';
      lines.add('${i + 1}. ${item.task.title} — ${item.reason}$effort');
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.focusNow,
      title: 'What matters now',
      text: lines.join('\n'),
    );
  }

  AskJotCueAnswer _dueSoon(AskJotCueContext context) {
    final now = context.now;
    final cutoff = now.add(const Duration(days: 14));
    final tasks = context.tasks.where((task) {
      final due = task.dueAt;
      return !task.isCompleted &&
          due != null &&
          !due.isBefore(now) &&
          !due.isAfter(cutoff);
    }).toList()..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final today = DateTime(now.year, now.month, now.day);
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final projects = context.projects.where((project) {
      final deadline = project.deadline;
      if (!project.isActive || deadline == null) return false;
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      return !deadlineDay.isBefore(today) && !deadlineDay.isAfter(cutoffDay);
    }).toList()..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    if (tasks.isEmpty && projects.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.dueSoon,
        title: 'Upcoming deadlines',
        text: 'Nothing with a known deadline is due in the next 14 days.',
      );
    }

    final lines = <String>[];
    for (final task in tasks.take(5)) {
      lines.add('• ${task.title} — ${_relativeDate(task.dueAt!, now)}');
    }
    for (final project in projects.take(3)) {
      lines.add(
        '• ${project.name} project — ${_relativeDate(project.deadline!, now)}',
      );
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.dueSoon,
      title: 'Upcoming deadlines',
      text: lines.join('\n'),
    );
  }

  AskJotCueAnswer _overdue(AskJotCueContext context) {
    final tasks =
        context.tasks
            .where(
              (task) =>
                  !task.isCompleted &&
                  task.dueAt != null &&
                  task.dueAt!.isBefore(context.now),
            )
            .toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (tasks.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.overdue,
        title: 'Overdue work',
        text: 'You have no overdue tasks with known deadlines.',
      );
    }

    final lines = tasks
        .take(6)
        .map((task) {
          final days = context.now.difference(task.dueAt!).inDays;
          final label = days <= 0
              ? 'overdue today'
              : '$days ${days == 1 ? 'day' : 'days'} overdue';
          return '• ${task.title} — $label';
        })
        .join('\n');
    return AskJotCueAnswer(
      intent: AskJotCueIntent.overdue,
      title: 'Overdue work',
      text: lines,
    );
  }

  AskJotCueAnswer _capacity(AskJotCueContext context) {
    final scheduling = context.scheduling;
    if (scheduling == null || !scheduling.isConfigured) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text:
            'Planning availability is not configured yet. Set your available days and hours in Settings so JotCue can calculate realistic free time.',
      );
    }
    if (!scheduling.isEnabledDay) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text:
            'Today is not enabled as a planning day in your availability settings.',
      );
    }
    if (scheduling.needsCalendarAccess) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text:
            'JotCue needs calendar read access before it can calculate free time around fixed commitments.',
      );
    }
    final availability = scheduling.availability;
    if (availability == null) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text: 'There is no usable planning window remaining today.',
      );
    }

    final accepted = context.dailyLoop.acceptedMinutes;
    final proposed = context.dailyLoop.proposedMinutes;
    final unscheduled = context.dailyLoop.unscheduledTaskCount;
    return AskJotCueAnswer(
      intent: AskJotCueIntent.capacityToday,
      title: 'Today’s capacity',
      text:
          '${_formatMinutes(availability.freeMinutes)} realistically free remains today. '
          '${_formatMinutes(accepted)} is already planned or completed and ${_formatMinutes(proposed)} is currently suggested.'
          '${unscheduled > 0 ? ' $unscheduled ${unscheduled == 1 ? 'task does' : 'tasks do'} not currently fit.' : ''}',
    );
  }

  AskJotCueAnswer _schedule(AskJotCueContext context) {
    final blocks = context.dailyLoop.todayBlocks;
    if (blocks.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.scheduleToday,
        title: 'Today’s plan',
        text: 'You do not have any accepted JotCue planning blocks today.',
      );
    }

    final lines = blocks
        .map((block) {
          final status = switch (block.status) {
            ScheduleBlockStatus.scheduled => 'scheduled',
            ScheduleBlockStatus.completed => 'completed',
            ScheduleBlockStatus.skipped => 'missed',
          };
          return '• ${_time(block.startsAt)}–${_time(block.endsAt)} ${block.title} · $status';
        })
        .join('\n');
    return AskJotCueAnswer(
      intent: AskJotCueIntent.scheduleToday,
      title: 'Today’s plan',
      text: lines,
    );
  }

  AskJotCueAnswer _nextBlock(AskJotCueContext context) {
    final block = context.dailyLoop.upNextBlock;
    if (block == null) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.nextBlock,
        title: 'Up next',
        text: 'There is no upcoming accepted JotCue block today.',
      );
    }
    final state = block.startsAt.isAfter(context.now)
        ? 'starts at ${_time(block.startsAt)}'
        : 'is in progress until ${_time(block.endsAt)}';
    return AskJotCueAnswer(
      intent: AskJotCueIntent.nextBlock,
      title: 'Up next',
      text:
          '${block.title} $state. Planned duration: ${_formatMinutes(block.duration.inMinutes)}.',
    );
  }

  AskJotCueAnswer _projects(AskJotCueContext context) {
    final active =
        context.projects.where((project) => project.isActive).toList()
          ..sort((a, b) {
            final priority = _priorityWeight(
              b.priority,
            ).compareTo(_priorityWeight(a.priority));
            if (priority != 0) return priority;
            final aDeadline = a.deadline;
            final bDeadline = b.deadline;
            if (aDeadline != null && bDeadline != null) {
              return aDeadline.compareTo(bDeadline);
            }
            if (aDeadline != null) return -1;
            if (bDeadline != null) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    if (active.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.projects,
        title: 'Active projects',
        text: 'You do not have any active Projects right now.',
      );
    }

    final tasksByProject = <String, List<Task>>{};
    for (final task in context.tasks.where((task) => !task.isCompleted)) {
      final projectId = task.projectId;
      if (projectId == null) continue;
      tasksByProject.putIfAbsent(projectId, () => []).add(task);
    }
    final lines = active
        .take(5)
        .map((project) {
          final open = tasksByProject[project.id]?.length ?? 0;
          final deadline = project.deadline == null
              ? ''
              : ' · ${_relativeDate(project.deadline!, context.now)}';
          return '• ${project.name} — $open open ${open == 1 ? 'task' : 'tasks'}$deadline';
        })
        .join('\n');
    return AskJotCueAnswer(
      intent: AskJotCueIntent.projects,
      title: 'Active projects',
      text: lines,
    );
  }

  AskJotCueAnswer _attention(AskJotCueContext context) {
    final lines = <String>[];
    final replanning = context.replanning;
    if (replanning != null && replanning.needsAttention) {
      if (replanning.pastBlockReviewCount > 0) {
        lines.add(
          '• ${replanning.pastBlockReviewCount} past planning ${replanning.pastBlockReviewCount == 1 ? 'block needs' : 'blocks need'} Completed/Missed review.',
        );
      }
      if (replanning.conflictCount > 0) {
        lines.add(
          '• ${replanning.conflictCount} scheduled ${replanning.conflictCount == 1 ? 'block conflicts' : 'blocks conflict'} with calendar or availability.',
        );
      }
      if (replanning.urgentCapacityCount > 0) {
        lines.add(
          '• ${replanning.urgentCapacityCount} urgent ${replanning.urgentCapacityCount == 1 ? 'capacity problem needs' : 'capacity problems need'} a decision.',
        );
      }
    }
    if (context.pulse.overdueCount > 0) {
      lines.add(
        '• ${context.pulse.overdueCount} overdue ${context.pulse.overdueCount == 1 ? 'task' : 'tasks'}.',
      );
    }
    final undatedHigh = context.tasks.where((task) {
      return !task.isCompleted &&
          task.dueAt == null &&
          (task.priority == PriorityLevel.high ||
              task.priority == PriorityLevel.critical);
    }).length;
    if (undatedHigh > 0) {
      lines.add(
        '• $undatedHigh high-priority ${undatedHigh == 1 ? 'task has' : 'tasks have'} no deadline.',
      );
    }

    if (lines.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.needsAttention,
        title: 'Needs attention',
        text:
            'JotCue is not currently flagging any planning issues that need review.',
      );
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.needsAttention,
      title: 'Needs attention',
      text: lines.join('\n'),
    );
  }

  AskJotCueAnswer _help() {
    return const AskJotCueAnswer(
      intent: AskJotCueIntent.help,
      title: 'Ask JotCue',
      text:
          'I can answer from your current JotCue plan. Try:\n'
          '• What should I do now?\n'
          '• What’s due soon?\n'
          '• Am I behind on anything?\n'
          '• How much time do I have today?\n'
          '• What’s next?\n'
          '• What needs attention?\n'
          '• Which projects are active?',
    );
  }

  AskJotCueAnswer _unknown() {
    return const AskJotCueAnswer(
      intent: AskJotCueIntent.unknown,
      title: 'I can help with your plan',
      text:
          'I don’t safely understand that request yet. For now, ask about focus, deadlines, overdue work, today’s capacity, your accepted schedule, active projects, or items that need review. Nothing is changed from this conversation.',
    );
  }
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9' ]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _containsAny(String value, List<String> phrases) {
  return phrases.any(value.contains);
}

int _priorityWeight(PriorityLevel priority) {
  return switch (priority) {
    PriorityLevel.critical => 4,
    PriorityLevel.high => 3,
    PriorityLevel.medium => 2,
    PriorityLevel.low => 1,
    PriorityLevel.none => 0,
  };
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _relativeDate(DateTime value, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final days = date.difference(today).inDays;
  if (days <= 0) return 'due today';
  if (days == 1) return 'due tomorrow';
  if (days <= 13) return 'due in $days days';
  return '${_month(value.month)} ${value.day}';
}

String _month(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
