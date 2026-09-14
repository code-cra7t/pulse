import '../../../core/models/priority_level.dart';
import '../../personal_graph/models/personal_graph.dart';
import '../../projects/models/project.dart';
import '../../pulse/models/daily_pulse_loop.dart';
import '../../pulse/models/pulse_overview.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/scheduling_day_state.dart';
import '../../tasks/data/task_dependency_analyzer.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_action_cue.dart';
import '../models/contextual_reasoning.dart';

/// Deterministic reasoning over JotCue's existing planning read models.
///
/// This engine is intentionally side-effect free. It does not mutate Tasks,
/// Projects, schedule blocks, Notes, or Personal Graph state, and it does not
/// call Hybrid AI. It combines already-authoritative local facts into one
/// explainable recommendation that later surfaces can reuse.
class ContextualReasoningEngine {
  const ContextualReasoningEngine();

  ContextualReasoningResult reason({
    required DateTime now,
    required List<Task> tasks,
    required List<Project> projects,
    required List<ScheduleBlock> blocks,
    SchedulingDayState? scheduling,
    ReplanningOverview? replanning,
    TaskDependencyAnalysis? dependencyAnalysis,
    PersonalGraph? personalGraph,
    PulseOverview? pulse,
    DailyPulseLoop? dailyLoop,
  }) {
    final analysis =
        dependencyAnalysis ?? const TaskDependencyAnalyzer().analyze(tasks);
    final projectById = <String, Project>{
      for (final project in projects) project.id: project,
    };
    final openTasks = tasks.where((task) => !task.isCompleted).toList();
    final readyTasks = <Task>[];
    var blockedCount = 0;
    var inactiveProjectTaskCount = 0;

    for (final task in openTasks) {
      final cue = analysis.cueForTask(task.id);
      if (cue?.isBlocked == true) {
        blockedCount += 1;
        continue;
      }
      final project = task.projectId == null
          ? null
          : projectById[task.projectId!];
      if (project != null && !project.isActive) {
        inactiveProjectTaskCount += 1;
        continue;
      }
      readyTasks.add(task);
    }

    final recommendations =
        readyTasks
            .map(
              (task) => _recommendation(
                task: task,
                now: now,
                tasks: tasks,
                project: task.projectId == null
                    ? null
                    : projectById[task.projectId!],
                blocks: blocks,
                scheduling: scheduling,
                replanning: replanning,
                graph: personalGraph,
                pulse: pulse,
                dailyLoop: dailyLoop,
              ),
            )
            .toList()
          ..sort(_compareRecommendations);

    final primary = recommendations.isEmpty ? null : recommendations.first;
    final alternative = recommendations.length < 2 ? null : recommendations[1];
    final limitations = <String>[];

    if (inactiveProjectTaskCount > 0) {
      limitations.add(
        '$inactiveProjectTaskCount open ${inactiveProjectTaskCount == 1 ? 'task belongs' : 'tasks belong'} to a paused, completed, or archived Project and ${inactiveProjectTaskCount == 1 ? 'was' : 'were'} not prioritized.',
      );
    }
    if (primary != null) {
      final estimate = primary.task.estimatedMinutes;
      if (estimate == null &&
          primary.executionWindow?.kind ==
              ContextualExecutionWindowKind.freeAvailability) {
        limitations.add(
          'The best Task has no effort estimate, so free-slot fit is approximate.',
        );
      }
      final graphContext = personalGraph?.taskContext(primary.task.id);
      final graphIssueCount = graphContext?.integrityIssues.length ?? 0;
      if (graphIssueCount > 0) {
        limitations.add(
          '$graphIssueCount Personal Graph ${graphIssueCount == 1 ? 'relationship has' : 'relationships have'} an integrity issue.',
        );
      }
      if (primary.executionWindow == null) {
        if (scheduling == null || !scheduling.canPropose) {
          limitations.add(
            'No usable availability window is configured for today, so timing is not confirmed.',
          );
        } else {
          limitations.add(
            'No remaining free slot is large enough for the current effort estimate.',
          );
        }
      }
    }
    if (replanning != null && !replanning.calendarConflictsChecked) {
      limitations.add(
        'External calendar conflicts were not fully checked for this reasoning snapshot.',
      );
    }

    return ContextualReasoningResult(
      generatedAt: now,
      primary: primary,
      alternative: alternative,
      readyTaskCount: recommendations.length,
      blockedTaskCount: blockedCount,
      confidence: _confidence(
        primary: primary,
        limitations: limitations,
        personalGraph: personalGraph,
      ),
      limitations: List<String>.unmodifiable(limitations),
    );
  }

  ContextualTaskRecommendation _recommendation({
    required Task task,
    required DateTime now,
    required List<Task> tasks,
    required Project? project,
    required List<ScheduleBlock> blocks,
    required SchedulingDayState? scheduling,
    required ReplanningOverview? replanning,
    required PersonalGraph? graph,
    required PulseOverview? pulse,
    required DailyPulseLoop? dailyLoop,
  }) {
    final downstreamCount = tasks.where((candidate) {
      return !candidate.isCompleted &&
          candidate.dependsOnTaskIds.contains(task.id);
    }).length;
    final graphContext = graph?.taskContext(task.id);
    final people =
        graphContext?.people.map((node) => node.label).toList() ??
        const <String>[];
    final relatedEvents = _relatedProjectEvents(graph, project, now);
    final relatedDecisionCount = _relatedProjectDecisionCount(graph, project);
    final scheduleWindow = _executionWindow(
      task: task,
      now: now,
      blocks: blocks,
      scheduling: scheduling,
      replanning: replanning,
    );
    final reasons = <String>[];
    var score = 0;

    if (scheduleWindow?.kind ==
        ContextualExecutionWindowKind.activeScheduleBlock) {
      score += 2600;
      reasons.add('Scheduled now');
    }

    final pulseIndex =
        pulse?.focusItems.indexWhere((item) => item.task.id == task.id) ?? -1;
    if (pulseIndex >= 0 && pulseIndex < 3) {
      score += switch (pulseIndex) {
        0 => 180,
        1 => 120,
        _ => 60,
      };
      reasons.add('Attention Engine focus signal');
    }
    if (dailyLoop?.upNextBlock?.taskId == task.id) {
      score += 100;
    }

    final dueSignal = _dueSignal(task.dueAt, now);
    score += dueSignal.score;
    if (dueSignal.label != null) reasons.add(dueSignal.label!);

    score += _priorityScore(task.priority);
    if (task.priority == PriorityLevel.critical) {
      reasons.add('Critical priority');
    } else if (task.priority == PriorityLevel.high) {
      reasons.add('High priority');
    }

    final projectSignal = _projectSignal(project, now);
    score += projectSignal.score;
    if (projectSignal.label != null) reasons.add(projectSignal.label!);

    if (downstreamCount > 0) {
      score += (downstreamCount > 5 ? 5 : downstreamCount) * 130;
      reasons.add(
        'Unlocks $downstreamCount downstream ${downstreamCount == 1 ? 'task' : 'tasks'}',
      );
    }

    if (scheduleWindow != null &&
        scheduleWindow.kind !=
            ContextualExecutionWindowKind.activeScheduleBlock) {
      final untilStart = scheduleWindow.startsAt.difference(now);
      if (scheduleWindow.kind ==
          ContextualExecutionWindowKind.replanningSuggestion) {
        score += 320;
        reasons.add('Has a recovery window from replanning');
      } else if (scheduleWindow.kind ==
          ContextualExecutionWindowKind.acceptedScheduleBlock) {
        if (untilStart <= const Duration(hours: 2)) {
          score += 420;
          reasons.add('Planned within the next 2 hours');
        } else if (_sameDay(scheduleWindow.startsAt, now)) {
          score += 220;
          reasons.add('Already planned today');
        }
      } else if (scheduleWindow.kind ==
          ContextualExecutionWindowKind.scheduleProposal) {
        score += 180;
        reasons.add('Schedule proposal fits today');
      } else if (scheduleWindow.kind ==
          ContextualExecutionWindowKind.freeAvailability) {
        score += 40;
      }
    }

    if (relatedEvents.isNotEmpty) {
      final nearest = _nearestProjectEvent(graph, project, now);
      if (nearest?.startsAt != null) {
        final days = _dayDifference(now, nearest!.startsAt!);
        if (days <= 0) {
          score += 180;
          reasons.add('Related event "${nearest.label}" is today');
        } else if (days <= 3) {
          score += 120;
          reasons.add('Related event "${nearest.label}" is in $days days');
        } else if (days <= 7) {
          score += 70;
          reasons.add('Related event "${nearest.label}" is this week');
        }
      }
    }

    if (reasons.isEmpty) reasons.add('Ready to work on');

    return ContextualTaskRecommendation(
      task: task,
      project: project,
      score: score,
      reasons: List<String>.unmodifiable(reasons),
      executionWindow: scheduleWindow,
      downstreamOpenTaskCount: downstreamCount,
      people: List<String>.unmodifiable(people),
      relatedEvents: List<String>.unmodifiable(relatedEvents),
      relatedDecisionCount: relatedDecisionCount,
    );
  }

  ContextualExecutionWindow? _executionWindow({
    required Task task,
    required DateTime now,
    required List<ScheduleBlock> blocks,
    required SchedulingDayState? scheduling,
    required ReplanningOverview? replanning,
  }) {
    final recovery = replanning == null
        ? <ReplanningSuggestion>[]
        : (replanning.issues
              .where(
                (issue) =>
                    issue.taskId == task.id &&
                    issue.suggestion != null &&
                    issue.suggestion!.endsAt.isAfter(now),
              )
              .map((issue) => issue.suggestion!)
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
    if (recovery.isNotEmpty) {
      final suggestion = recovery.first;
      return ContextualExecutionWindow(
        kind: ContextualExecutionWindowKind.replanningSuggestion,
        startsAt: suggestion.startsAt,
        endsAt: suggestion.endsAt,
      );
    }

    final accepted =
        blocks
            .where(
              (block) =>
                  block.taskId == task.id &&
                  block.status == ScheduleBlockStatus.scheduled &&
                  block.endsAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (accepted.isNotEmpty) {
      final block = accepted.first;
      return ContextualExecutionWindow(
        kind: !block.startsAt.isAfter(now)
            ? ContextualExecutionWindowKind.activeScheduleBlock
            : ContextualExecutionWindowKind.acceptedScheduleBlock,
        startsAt: block.startsAt,
        endsAt: block.endsAt,
      );
    }

    final proposed = scheduling?.proposal?.proposals
        .where(
          (proposal) =>
              proposal.taskId == task.id && proposal.endsAt.isAfter(now),
        )
        .toList();
    proposed?.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (proposed != null && proposed.isNotEmpty) {
      final proposal = proposed.first;
      return ContextualExecutionWindow(
        kind: ContextualExecutionWindowKind.scheduleProposal,
        startsAt: proposal.startsAt,
        endsAt: proposal.endsAt,
      );
    }

    if (scheduling == null || !scheduling.canPropose) return null;
    final availability = scheduling.availability;
    if (availability == null) return null;
    final requiredMinutes = task.estimatedMinutes ?? 30;
    final slots = availability.freeSlots.where((slot) {
      final start = slot.startsAt.isBefore(now) ? now : slot.startsAt;
      return slot.endsAt.difference(start).inMinutes >= requiredMinutes;
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (slots.isEmpty) return null;
    final slot = slots.first;
    final startsAt = slot.startsAt.isBefore(now) ? now : slot.startsAt;
    return ContextualExecutionWindow(
      kind: ContextualExecutionWindowKind.freeAvailability,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: requiredMinutes)),
    );
  }

  List<String> _relatedProjectEvents(
    PersonalGraph? graph,
    Project? project,
    DateTime now,
  ) {
    if (graph == null || project == null) return const <String>[];
    final projectNode = graph.node(PersonalGraphNodeType.project, project.id);
    if (projectNode == null) return const <String>[];
    final events =
        graph
            .incoming(
              projectNode.id,
              type: PersonalGraphEdgeType.relatesToProject,
            )
            .map((edge) => graph.nodes[edge.fromNodeId])
            .whereType<PersonalGraphNode>()
            .where(
              (node) =>
                  node.type == PersonalGraphNodeType.event &&
                  (node.startsAt == null ||
                      !node.startsAt!.isBefore(_dayStart(now))),
            )
            .toList()
          ..sort((a, b) {
            final aDate = a.startsAt;
            final bDate = b.startsAt;
            if (aDate == null && bDate == null) {
              return a.label.compareTo(b.label);
            }
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
    return events.take(3).map((node) => node.label).toList(growable: false);
  }

  PersonalGraphNode? _nearestProjectEvent(
    PersonalGraph? graph,
    Project? project,
    DateTime now,
  ) {
    if (graph == null || project == null) return null;
    final projectNode = graph.node(PersonalGraphNodeType.project, project.id);
    if (projectNode == null) return null;
    final events =
        graph
            .incoming(
              projectNode.id,
              type: PersonalGraphEdgeType.relatesToProject,
            )
            .map((edge) => graph.nodes[edge.fromNodeId])
            .whereType<PersonalGraphNode>()
            .where(
              (node) =>
                  node.type == PersonalGraphNodeType.event &&
                  node.startsAt != null &&
                  !node.startsAt!.isBefore(_dayStart(now)),
            )
            .toList()
          ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
    return events.isEmpty ? null : events.first;
  }

  int _relatedProjectDecisionCount(PersonalGraph? graph, Project? project) {
    if (graph == null || project == null) return 0;
    final projectNode = graph.node(PersonalGraphNodeType.project, project.id);
    if (projectNode == null) return 0;
    return graph
        .incoming(projectNode.id, type: PersonalGraphEdgeType.belongsToProject)
        .map((edge) => graph.nodes[edge.fromNodeId])
        .whereType<PersonalGraphNode>()
        .where((node) => node.type == PersonalGraphNodeType.decision)
        .length;
  }

  _ReasonSignal _dueSignal(DateTime? dueAt, DateTime now) {
    if (dueAt == null) return const _ReasonSignal();
    if (dueAt.isBefore(now)) {
      final overdueDays = now.difference(dueAt).inDays;
      return _ReasonSignal(
        score: 1900 + (overdueDays > 30 ? 30 : overdueDays) * 8,
        label: overdueDays <= 0
            ? 'Overdue'
            : 'Overdue by $overdueDays ${overdueDays == 1 ? 'day' : 'days'}',
      );
    }
    final days = _dayDifference(now, dueAt);
    if (days <= 0) return const _ReasonSignal(score: 1050, label: 'Due today');
    if (days == 1) {
      return const _ReasonSignal(score: 880, label: 'Due tomorrow');
    }
    if (days <= 3) {
      return _ReasonSignal(score: 720, label: 'Due in $days days');
    }
    if (days <= 7) {
      return _ReasonSignal(score: 520, label: 'Due in $days days');
    }
    if (days <= 14) {
      return _ReasonSignal(score: 300, label: 'Due in $days days');
    }
    return const _ReasonSignal(score: 100);
  }

  _ReasonSignal _projectSignal(Project? project, DateTime now) {
    if (project == null || !project.isActive) return const _ReasonSignal();
    var score = switch (project.priority) {
      PriorityLevel.critical => 130,
      PriorityLevel.high => 90,
      PriorityLevel.medium => 50,
      PriorityLevel.low => 20,
      PriorityLevel.none => 0,
    };
    String? label;
    final deadline = project.deadline;
    if (deadline != null) {
      if (deadline.isBefore(now)) {
        score += 430;
        label = 'Project deadline is overdue';
      } else {
        final days = _dayDifference(now, deadline);
        if (days <= 0) {
          score += 330;
          label = 'Project deadline today';
        } else if (days == 1) {
          score += 280;
          label = 'Project deadline tomorrow';
        } else if (days <= 3) {
          score += 220;
          label = 'Project deadline in $days days';
        } else if (days <= 7) {
          score += 140;
          label = 'Project deadline in $days days';
        }
      }
    }
    return _ReasonSignal(score: score, label: label);
  }

  int _priorityScore(PriorityLevel priority) => switch (priority) {
    PriorityLevel.critical => 420,
    PriorityLevel.high => 290,
    PriorityLevel.medium => 160,
    PriorityLevel.low => 70,
    PriorityLevel.none => 0,
  };

  int _compareRecommendations(
    ContextualTaskRecommendation a,
    ContextualTaskRecommendation b,
  ) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final aDue = a.task.dueAt;
    final bDue = b.task.dueAt;
    if (aDue != null && bDue != null) {
      final due = aDue.compareTo(bDue);
      if (due != 0) return due;
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }
    return a.task.title.toLowerCase().compareTo(b.task.title.toLowerCase());
  }

  ContextualReasoningConfidence _confidence({
    required ContextualTaskRecommendation? primary,
    required List<String> limitations,
    required PersonalGraph? personalGraph,
  }) {
    if (primary == null) return ContextualReasoningConfidence.low;
    if (limitations.isNotEmpty || personalGraph == null) {
      return ContextualReasoningConfidence.medium;
    }
    return ContextualReasoningConfidence.high;
  }

  int _dayDifference(DateTime from, DateTime to) {
    return _dayStart(to).difference(_dayStart(from)).inDays;
  }

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ReasonSignal {
  const _ReasonSignal({this.score = 0, this.label});

  final int score;
  final String? label;
}
