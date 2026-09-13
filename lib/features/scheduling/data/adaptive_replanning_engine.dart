import '../../../core/models/priority_level.dart';
import '../../calendar/models/availability_summary.dart';
import '../../calendar/models/calendar_busy_event.dart';
import '../../projects/models/project.dart';
import '../../tasks/models/task.dart';
import '../models/replanning_overview.dart';
import '../models/schedule_block.dart';
import '../models/scheduling_preferences.dart';

/// Detects schedule drift and prepares deterministic recovery suggestions.
///
/// The engine never mutates Tasks, Projects, schedule blocks, or calendars.
/// Every result is advisory until the user explicitly applies an action.
class AdaptiveReplanningEngine {
  const AdaptiveReplanningEngine();

  ReplanningOverview build({
    required DateTime now,
    required SchedulingPreferences preferences,
    required List<ScheduleBlock> blocks,
    required List<Task> tasks,
    required List<Project> projects,
    required List<CalendarBusyEvent> calendarBusyEvents,
    required List<AvailabilitySummary> horizonAvailability,
    required bool calendarConflictsChecked,
  }) {
    final horizonEnd = horizonAvailability.isEmpty
        ? now
        : horizonAvailability.last.windowEnd;
    final issues = <ReplanningIssue>[];

    final scheduledBlocks = blocks
        .where((block) => block.status == ScheduleBlockStatus.scheduled)
        .toList(growable: false);
    final taskById = <String, Task>{for (final task in tasks) task.id: task};

    for (final block in scheduledBlocks) {
      final canMove = taskById[block.taskId]?.isFlexible ?? true;
      if (!block.endsAt.isAfter(now)) {
        issues.add(
          ReplanningIssue(
            id: 'past-${block.id}',
            kind: ReplanningIssueKind.pastBlockReview,
            title: block.title,
            message:
                'This planned block has passed. Confirm whether you completed it or move it to another free time.',
            taskId: block.taskId,
            projectId: block.projectId,
            block: block,
            suggestion: canMove
                ? _findReplacement(
                    block: block,
                    now: now,
                    preferences: preferences,
                    blocks: blocks,
                    availability: horizonAvailability,
                  )
                : null,
          ),
        );
        continue;
      }

      if (!_fitsPreferences(block, preferences)) {
        issues.add(
          ReplanningIssue(
            id: 'availability-${block.id}',
            kind: ReplanningIssueKind.outsideAvailability,
            title: block.title,
            message:
                'This block no longer fits your current planning availability.',
            taskId: block.taskId,
            projectId: block.projectId,
            block: block,
            suggestion: canMove
                ? _findReplacement(
                    block: block,
                    now: now,
                    preferences: preferences,
                    blocks: blocks,
                    availability: horizonAvailability,
                  )
                : null,
          ),
        );
        continue;
      }

      if (calendarConflictsChecked &&
          calendarBusyEvents.any(
            (event) =>
                event.isValid &&
                _overlaps(
                  block.startsAt,
                  block.endsAt,
                  event.startsAt,
                  event.endsAt,
                ),
          )) {
        issues.add(
          ReplanningIssue(
            id: 'calendar-${block.id}',
            kind: ReplanningIssueKind.calendarConflict,
            title: block.title,
            message:
                'Your device calendar now has a fixed commitment during this JotCue block.',
            taskId: block.taskId,
            projectId: block.projectId,
            block: block,
            suggestion: canMove
                ? _findReplacement(
                    block: block,
                    now: now,
                    preferences: preferences,
                    blocks: blocks,
                    availability: horizonAvailability,
                  )
                : null,
          ),
        );
      }
    }

    final problemBlockIds = issues
        .map((issue) => issue.block?.id)
        .whereType<String>()
        .toSet();
    issues.addAll(
      _urgentCapacityIssues(
        now: now,
        horizonEnd: horizonEnd,
        preferences: preferences,
        blocks: blocks,
        tasks: tasks,
        projects: projects,
        availability: horizonAvailability,
        problemBlockIds: problemBlockIds,
      ),
    );

    issues.sort((a, b) {
      final kind = _kindRank(a.kind).compareTo(_kindRank(b.kind));
      if (kind != 0) {
        return kind;
      }
      final aTime = a.block?.startsAt;
      final bTime = b.block?.startsAt;
      if (aTime != null && bTime != null) {
        return aTime.compareTo(bTime);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return ReplanningOverview(
      generatedAt: now,
      horizonEnd: horizonEnd,
      issues: List.unmodifiable(issues),
      calendarConflictsChecked: calendarConflictsChecked,
    );
  }

  ReplanningSuggestion? _findReplacement({
    required ScheduleBlock block,
    required DateTime now,
    required SchedulingPreferences preferences,
    required List<ScheduleBlock> blocks,
    required List<AvailabilitySummary> availability,
  }) {
    final durationMinutes = block.duration.inMinutes;
    if (durationMinutes <= 0) {
      return null;
    }

    for (final summary in availability) {
      final date = summary.windowStart;
      final usedFocusMinutes = blocks
          .where(
            (other) =>
                other.id != block.id &&
                other.countsTowardFocusBudget &&
                _sameDay(other.startsAt, date),
          )
          .fold<int>(0, (sum, other) => sum + other.duration.inMinutes);
      if (usedFocusMinutes + durationMinutes >
          preferences.maxFocusMinutesPerDay) {
        continue;
      }

      for (final slot in summary.freeSlots) {
        var start = slot.startsAt;
        if (start.isBefore(now)) {
          start = now;
        }
        final end = start.add(Duration(minutes: durationMinutes));
        if (!end.isAfter(start) || end.isAfter(slot.endsAt)) {
          continue;
        }
        return ReplanningSuggestion(startsAt: start, endsAt: end);
      }
    }
    return null;
  }

  List<ReplanningIssue> _urgentCapacityIssues({
    required DateTime now,
    required DateTime horizonEnd,
    required SchedulingPreferences preferences,
    required List<ScheduleBlock> blocks,
    required List<Task> tasks,
    required List<Project> projects,
    required List<AvailabilitySummary> availability,
    required Set<String> problemBlockIds,
  }) {
    if (availability.isEmpty) {
      return const [];
    }

    final projectById = <String, Project>{
      for (final project in projects) project.id: project,
    };
    final taskById = <String, Task>{for (final task in tasks) task.id: task};
    final candidates = tasks.where((task) {
      if (task.isCompleted || task.id.isEmpty || task.dueAt == null) {
        return false;
      }
      final project = task.projectId == null
          ? null
          : projectById[task.projectId!];
      if (project != null && !project.isActive) {
        return false;
      }
      return !_day(task.dueAt!).isAfter(_day(horizonEnd));
    }).toList();

    candidates.sort((a, b) {
      final due = a.dueAt!.compareTo(b.dueAt!);
      if (due != 0) {
        return due;
      }
      return _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
    });

    final capacity = <DateTime, int>{};
    for (final summary in availability) {
      final day = _day(summary.windowStart);
      final usedFocusMinutes = blocks
          .where(
            (block) =>
                block.countsTowardFocusBudget && _sameDay(block.startsAt, day),
          )
          .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
      final focusRemaining =
          preferences.maxFocusMinutesPerDay - usedFocusMinutes;
      capacity[day] = _min(
        summary.freeMinutes,
        focusRemaining < 0 ? 0 : focusRemaining,
      );
    }

    final issues = <ReplanningIssue>[];
    final reservedDisplacementBlockIds = <String>{};
    for (final task in candidates) {
      final totalMinutes =
          task.estimatedMinutes ?? preferences.defaultTaskMinutes;
      final accountedMinutes = blocks
          .where(
            (block) =>
                block.taskId == task.id &&
                (block.status == ScheduleBlockStatus.completed ||
                    (block.status == ScheduleBlockStatus.scheduled &&
                        block.endsAt.isAfter(now))),
          )
          .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
      var remaining = totalMinutes - accountedMinutes;
      if (remaining <= 0) {
        continue;
      }

      final due = task.dueAt!;
      final eligibleDays = capacity.keys.where((day) {
        if (due.isBefore(now)) {
          return false;
        }
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
        return !dayEnd.isAfter(due) || _sameDay(day, due);
      }).toList()..sort();

      final availableBeforeDue = eligibleDays.fold<int>(
        0,
        (sum, day) => sum + (capacity[day] ?? 0),
      );
      if (due.isBefore(now) || availableBeforeDue < remaining) {
        final shortfall = due.isBefore(now)
            ? remaining
            : remaining - availableBeforeDue;
        final displacement = due.isBefore(now)
            ? null
            : _findDisplacement(
                urgentTask: task,
                shortfallMinutes: shortfall,
                now: now,
                preferences: preferences,
                blocks: blocks,
                taskById: taskById,
                availability: availability,
                problemBlockIds: {
                  ...problemBlockIds,
                  ...reservedDisplacementBlockIds,
                },
              );
        if (displacement != null) {
          reservedDisplacementBlockIds.add(displacement.block.id);
        }
        _consumeCapacity(capacity, eligibleDays, remaining);
        issues.add(
          ReplanningIssue(
            id: 'urgent-${task.id}',
            kind: ReplanningIssueKind.urgentCapacity,
            title: task.title,
            message: due.isBefore(now)
                ? 'This task is overdue with ${_minutesLabel(remaining)} of estimated work still unaccounted for.'
                : displacement == null
                ? 'About ${_minutesLabel(shortfall)} of this task still cannot fit before its deadline.'
                : 'Move “${displacement.block.title}” later to free ${_minutesLabel(displacement.block.duration.inMinutes)} before this deadline.',
            taskId: task.id,
            projectId: task.projectId,
            block: displacement?.block,
            suggestion: displacement?.suggestion,
            remainingMinutes: remaining,
          ),
        );
        continue;
      }

      _consumeCapacity(capacity, eligibleDays, remaining);
    }
    return issues;
  }

  _Displacement? _findDisplacement({
    required Task urgentTask,
    required int shortfallMinutes,
    required DateTime now,
    required SchedulingPreferences preferences,
    required List<ScheduleBlock> blocks,
    required Map<String, Task> taskById,
    required List<AvailabilitySummary> availability,
    required Set<String> problemBlockIds,
  }) {
    final due = urgentTask.dueAt;
    if (due == null) {
      return null;
    }
    final candidates = blocks.where((block) {
      if (!block.occupiesTime ||
          block.id.isEmpty ||
          problemBlockIds.contains(block.id) ||
          !block.endsAt.isAfter(now) ||
          block.startsAt.isAfter(due)) {
        return false;
      }
      final blockTask = taskById[block.taskId];
      if (blockTask == null || !blockTask.isFlexible) {
        return false;
      }
      if (block.duration.inMinutes < shortfallMinutes) {
        return false;
      }
      final lowerPriority =
          _priorityRank(blockTask.priority) <
          _priorityRank(urgentTask.priority);
      final laterDeadline =
          blockTask.dueAt == null || blockTask.dueAt!.isAfter(due);
      return lowerPriority || laterDeadline;
    }).toList();

    candidates.sort((a, b) {
      final aTask = taskById[a.taskId]!;
      final bTask = taskById[b.taskId]!;
      final priority = _priorityRank(
        aTask.priority,
      ).compareTo(_priorityRank(bTask.priority));
      if (priority != 0) {
        return priority;
      }
      return b.startsAt.compareTo(a.startsAt);
    });

    for (final block in candidates) {
      final suggestion = _findReplacement(
        block: block,
        now: due.add(const Duration(minutes: 1)),
        preferences: preferences,
        blocks: blocks,
        availability: availability,
      );
      if (suggestion != null) {
        return _Displacement(block: block, suggestion: suggestion);
      }
    }
    return null;
  }

  void _consumeCapacity(
    Map<DateTime, int> capacity,
    List<DateTime> eligibleDays,
    int requestedMinutes,
  ) {
    var remaining = requestedMinutes;
    for (final day in eligibleDays) {
      if (remaining <= 0) {
        return;
      }
      final availableMinutes = capacity[day] ?? 0;
      if (availableMinutes <= 0) {
        continue;
      }
      final consumed = _min(remaining, availableMinutes);
      capacity[day] = availableMinutes - consumed;
      remaining -= consumed;
    }
  }

  bool _fitsPreferences(
    ScheduleBlock block,
    SchedulingPreferences preferences,
  ) {
    final day = _day(block.startsAt);
    if (!preferences.isEnabledOn(day)) {
      return false;
    }
    if (block.startsAt.isBefore(preferences.startFor(day)) ||
        block.endsAt.isAfter(preferences.endFor(day))) {
      return false;
    }
    if (preferences.protectLunch &&
        _overlaps(
          block.startsAt,
          block.endsAt,
          preferences.lunchStartFor(day),
          preferences.lunchEndFor(day),
        )) {
      return false;
    }
    return true;
  }
}

class _Displacement {
  const _Displacement({required this.block, required this.suggestion});

  final ScheduleBlock block;
  final ReplanningSuggestion suggestion;
}

int _kindRank(ReplanningIssueKind kind) => switch (kind) {
  ReplanningIssueKind.pastBlockReview => 0,
  ReplanningIssueKind.calendarConflict => 1,
  ReplanningIssueKind.outsideAvailability => 2,
  ReplanningIssueKind.urgentCapacity => 3,
};

int _priorityRank(PriorityLevel priority) => switch (priority) {
  PriorityLevel.critical => 4,
  PriorityLevel.high => 3,
  PriorityLevel.medium => 2,
  PriorityLevel.low => 1,
  PriorityLevel.none => 0,
};

bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

int _min(int a, int b) => a < b ? a : b;

String _minutesLabel(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}
