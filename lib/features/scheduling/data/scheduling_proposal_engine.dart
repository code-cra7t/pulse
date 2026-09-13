import '../../../core/models/priority_level.dart';
import '../../calendar/models/availability_summary.dart';
import '../../projects/models/project.dart';
import '../../tasks/models/task.dart';
import '../models/schedule_block.dart';
import '../models/schedule_proposal.dart';
import '../models/scheduling_preferences.dart';

class SchedulingProposalEngine {
  const SchedulingProposalEngine();

  DayScheduleProposal build({
    required DateTime now,
    required DateTime date,
    required SchedulingPreferences preferences,
    required AvailabilitySummary availability,
    required List<Task> tasks,
    required List<Project> projects,
    required List<ScheduleBlock> existingBlocks,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final projectById = <String, Project>{
      for (final project in projects) project.id: project,
    };
    final acceptedToday = existingBlocks
        .where((block) {
          return block.occupiesTime && _sameDay(block.startsAt, day);
        })
        .toList(growable: false);
    final acceptedMinutes = acceptedToday.fold<int>(
      0,
      (sum, block) => sum + block.duration.inMinutes,
    );
    var remainingDailyBudget =
        preferences.maxFocusMinutesPerDay - acceptedMinutes;
    if (remainingDailyBudget < 0) {
      remainingDailyBudget = 0;
    }

    final plannedFutureByTask = <String, int>{};
    for (final block in existingBlocks) {
      if (!block.occupiesTime || !block.endsAt.isAfter(now)) {
        continue;
      }
      plannedFutureByTask.update(
        block.taskId,
        (value) => value + block.duration.inMinutes,
        ifAbsent: () => block.duration.inMinutes,
      );
    }

    final candidates = <_Candidate>[];
    for (final task in tasks) {
      if (task.isCompleted || task.id.isEmpty) {
        continue;
      }
      final project = task.projectId == null
          ? null
          : projectById[task.projectId!];
      if (project != null && !project.isActive) {
        continue;
      }

      final assumedEffort = task.estimatedMinutes == null;
      final totalMinutes =
          task.estimatedMinutes ?? preferences.defaultTaskMinutes;
      final alreadyPlanned = plannedFutureByTask[task.id] ?? 0;
      final remaining = totalMinutes - alreadyPlanned;
      if (remaining <= 0) {
        continue;
      }
      candidates.add(
        _Candidate(
          task: task,
          project: project,
          remainingMinutes: remaining,
          assumedEffort: assumedEffort,
          score: _score(task, project, day, now),
        ),
      );
    }
    candidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final aDue = a.task.dueAt;
      final bDue = b.task.dueAt;
      if (aDue != null && bDue != null) {
        final dueCompare = aDue.compareTo(bDue);
        if (dueCompare != 0) {
          return dueCompare;
        }
      } else if (aDue != null) {
        return -1;
      } else if (bDue != null) {
        return 1;
      }
      return a.task.title.toLowerCase().compareTo(b.task.title.toLowerCase());
    });

    final slots = availability.freeSlots
        .map((slot) => _MutableSlot(slot.startsAt, slot.endsAt))
        .toList(growable: false);
    final proposals = <ScheduleProposal>[];
    var assumedEffortCount = 0;
    final scheduledMinutesByTask = <String, int>{};

    for (final candidate in candidates) {
      if (remainingDailyBudget <= 0) {
        break;
      }
      var remaining = candidate.remainingMinutes;
      var scheduledAny = false;

      for (final slot in slots) {
        while (remaining > 0 && remainingDailyBudget > 0) {
          if (!slot.end.isAfter(slot.cursor)) {
            break;
          }

          final availableMinutes = slot.end.difference(slot.cursor).inMinutes;
          if (availableMinutes <= 0) {
            break;
          }

          final target = _min3(
            remaining,
            preferences.preferredBlockMinutes,
            remainingDailyBudget,
          );
          final finalChunk = remaining <= preferences.minimumBlockMinutes;
          final minimumNeeded = finalChunk
              ? remaining
              : preferences.minimumBlockMinutes;
          if (availableMinutes < minimumNeeded || target <= 0) {
            break;
          }

          var duration = target;
          if (duration > availableMinutes) {
            duration = availableMinutes;
          }
          if (!finalChunk && duration < preferences.minimumBlockMinutes) {
            break;
          }

          final startsAt = slot.cursor;
          final endsAt = startsAt.add(Duration(minutes: duration));
          proposals.add(
            ScheduleProposal(
              id: '${candidate.task.id}-${startsAt.millisecondsSinceEpoch}-$duration',
              taskId: candidate.task.id,
              title: candidate.task.title,
              projectId: candidate.task.projectId,
              startsAt: startsAt,
              endsAt: endsAt,
              reason: _reason(candidate.task, candidate.project, day, now),
              score: candidate.score,
              assumedEffort: candidate.assumedEffort,
            ),
          );
          scheduledAny = true;
          remaining -= duration;
          remainingDailyBudget -= duration;
          slot.cursor = endsAt.add(Duration(minutes: preferences.breakMinutes));
        }
        if (remaining <= 0 || remainingDailyBudget <= 0) {
          break;
        }
      }

      if (scheduledAny) {
        scheduledMinutesByTask[candidate.task.id] =
            candidate.remainingMinutes - remaining;
        if (candidate.assumedEffort) {
          assumedEffortCount += 1;
        }
      }
    }

    proposals.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final proposedMinutes = proposals.fold<int>(
      0,
      (sum, proposal) => sum + proposal.minutes,
    );

    return DayScheduleProposal(
      date: day,
      freeMinutes: availability.freeMinutes,
      acceptedMinutes: acceptedMinutes,
      proposedMinutes: proposedMinutes,
      proposals: List.unmodifiable(proposals),
      unscheduledTaskCount: candidates.where((candidate) {
        final scheduled = scheduledMinutesByTask[candidate.task.id] ?? 0;
        return scheduled < candidate.remainingMinutes;
      }).length,
      assumedEffortCount: assumedEffortCount,
    );
  }

  int _score(Task task, Project? project, DateTime day, DateTime now) {
    var score = switch (task.priority) {
      PriorityLevel.critical => 420,
      PriorityLevel.high => 300,
      PriorityLevel.medium => 170,
      PriorityLevel.low => 70,
      PriorityLevel.none => 0,
    };

    final dueAt = task.dueAt;
    if (dueAt != null) {
      if (dueAt.isBefore(now)) {
        score += 2400;
      } else {
        final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
        final days = dueDay.difference(day).inDays;
        score += switch (days) {
          <= 0 => 1100,
          1 => 900,
          2 => 780,
          3 => 680,
          <= 7 => 560 - (days * 20),
          <= 14 => 300 - (days * 8),
          _ => 80,
        };
      }
    }

    if (project != null) {
      score += switch (project.priority) {
        PriorityLevel.critical => 140,
        PriorityLevel.high => 95,
        PriorityLevel.medium => 50,
        PriorityLevel.low => 20,
        PriorityLevel.none => 0,
      };
      final deadline = project.deadline;
      if (deadline != null) {
        final deadlineDay = DateTime(
          deadline.year,
          deadline.month,
          deadline.day,
        );
        final days = deadlineDay.difference(day).inDays;
        if (days <= 0) {
          score += 260;
        } else if (days <= 3) {
          score += 180;
        } else if (days <= 7) {
          score += 100;
        }
      }
    }

    return score;
  }

  String _reason(Task task, Project? project, DateTime day, DateTime now) {
    final dueAt = task.dueAt;
    if (dueAt != null) {
      if (dueAt.isBefore(now)) {
        return 'Overdue task';
      }
      final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
      final days = dueDay.difference(day).inDays;
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
    if (deadline != null) {
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      final days = deadlineDay.difference(day).inDays;
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
    return project?.name ?? 'Open task';
  }
}

class _Candidate {
  const _Candidate({
    required this.task,
    required this.project,
    required this.remainingMinutes,
    required this.assumedEffort,
    required this.score,
  });

  final Task task;
  final Project? project;
  final int remainingMinutes;
  final bool assumedEffort;
  final int score;
}

class _MutableSlot {
  _MutableSlot(DateTime start, this.end) : cursor = start;

  DateTime cursor;
  final DateTime end;
}

bool _sameDay(DateTime value, DateTime day) {
  return value.year == day.year &&
      value.month == day.month &&
      value.day == day.day;
}

int _min3(int a, int b, int c) {
  var result = a < b ? a : b;
  if (c < result) {
    result = c;
  }
  return result;
}
