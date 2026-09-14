import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/calendar/models/availability_summary.dart';
import 'package:pulse/features/personal_graph/models/personal_graph.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/reasoning/data/contextual_reasoning_engine.dart';
import 'package:pulse/features/reasoning/models/contextual_reasoning.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:pulse/features/scheduling/models/scheduling_day_state.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const engine = ContextualReasoningEngine();
  final now = DateTime(2026, 9, 14, 10);

  Project project({
    String id = 'project',
    String name = 'Launch',
    PriorityLevel priority = PriorityLevel.high,
    DateTime? deadline,
  }) {
    return Project(
      id: id,
      userId: 'user',
      name: name,
      priority: priority,
      deadline: deadline,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 14),
    );
  }

  Task task({
    required String id,
    required String title,
    PriorityLevel priority = PriorityLevel.medium,
    DateTime? dueAt,
    String? projectId,
    int? estimatedMinutes = 60,
    List<String> dependsOnTaskIds = const <String>[],
    String? waitingFor,
  }) {
    return Task(
      id: id,
      userId: 'user',
      title: title,
      isCompleted: false,
      sourceNoteId: 'note-$id',
      sourceLineIndex: 0,
      priority: priority,
      dueAt: dueAt,
      projectId: projectId,
      estimatedMinutes: estimatedMinutes,
      dependsOnTaskIds: dependsOnTaskIds,
      waitingFor: waitingFor,
    );
  }

  ScheduleBlock block({
    required String id,
    required String taskId,
    required DateTime startsAt,
    int minutes = 60,
  }) {
    return ScheduleBlock(
      id: id,
      userId: 'user',
      taskId: taskId,
      title: taskId,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: minutes)),
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    );
  }

  SchedulingDayState scheduling(
    List<AvailabilitySlot> slots, {
    DayScheduleProposal? proposal,
  }) {
    final preferences = SchedulingPreferences.defaults().copyWith(
      isConfigured: true,
      availableWeekdays: [DateTime.monday],
    );
    return SchedulingDayState(
      date: DateTime(2026, 9, 14),
      preferences: preferences,
      calendarSupported: false,
      calendarAccess: true,
      acceptedBlocks: const [],
      availability: AvailabilitySummary(
        windowStart: DateTime(2026, 9, 14, 9),
        windowEnd: DateTime(2026, 9, 14, 18),
        busyMinutes: 0,
        freeMinutes: slots.fold(
          0,
          (sum, slot) => sum + slot.duration.inMinutes,
        ),
        freeSlots: slots,
      ),
      proposal: proposal,
    );
  }

  test('never recommends a blocked Task over ready work', () {
    final blocked = task(
      id: 'blocked',
      title: 'Critical blocked task',
      priority: PriorityLevel.critical,
      dueAt: DateTime(2026, 9, 14, 12),
      waitingFor: 'Susan',
    );
    final ready = task(
      id: 'ready',
      title: 'Ready report',
      priority: PriorityLevel.high,
      dueAt: DateTime(2026, 9, 15),
    );

    final result = engine.reason(
      now: now,
      tasks: [blocked, ready],
      projects: const [],
      blocks: const [],
    );

    expect(result.primary?.task.id, 'ready');
    expect(result.blockedTaskCount, 1);
  });

  test('prerequisite work gains weight from downstream impact', () {
    final unlocker = task(id: 'unlocker', title: 'Get approval');
    final peer = task(id: 'peer', title: 'Tidy notes');
    final dependentOne = task(
      id: 'dependent-1',
      title: 'Publish draft',
      dependsOnTaskIds: const ['unlocker'],
    );
    final dependentTwo = task(
      id: 'dependent-2',
      title: 'Send launch email',
      dependsOnTaskIds: const ['unlocker'],
    );

    final result = engine.reason(
      now: now,
      tasks: [unlocker, peer, dependentOne, dependentTwo],
      projects: const [],
      blocks: const [],
    );

    expect(result.primary?.task.id, 'unlocker');
    expect(result.primary?.downstreamOpenTaskCount, 2);
    expect(result.primary?.reasons.join(' '), contains('Unlocks 2'));
  });

  test(
    'an active accepted block is treated as the strongest current signal',
    () {
      final scheduled = task(id: 'scheduled', title: 'Current focus');
      final overdue = task(
        id: 'overdue',
        title: 'Older task',
        dueAt: DateTime(2026, 9, 13),
      );

      final result = engine.reason(
        now: now,
        tasks: [scheduled, overdue],
        projects: const [],
        blocks: [
          block(
            id: 'current',
            taskId: 'scheduled',
            startsAt: DateTime(2026, 9, 14, 9, 30),
          ),
        ],
      );

      expect(result.primary?.task.id, 'scheduled');
      expect(
        result.primary?.executionWindow?.kind,
        ContextualExecutionWindowKind.activeScheduleBlock,
      );
      expect(result.primary?.primaryReason, 'Scheduled now');
    },
  );

  test(
    'uses earliest fitting availability when Task is not already planned',
    () {
      final candidate = task(
        id: 'candidate',
        title: 'Write proposal',
        estimatedMinutes: 90,
      );
      final state = scheduling([
        AvailabilitySlot(
          startsAt: DateTime(2026, 9, 14, 10, 30),
          endsAt: DateTime(2026, 9, 14, 11),
        ),
        AvailabilitySlot(
          startsAt: DateTime(2026, 9, 14, 13),
          endsAt: DateTime(2026, 9, 14, 15),
        ),
      ]);

      final result = engine.reason(
        now: now,
        tasks: [candidate],
        projects: const [],
        blocks: const [],
        scheduling: state,
      );

      expect(
        result.primary?.executionWindow?.kind,
        ContextualExecutionWindowKind.freeAvailability,
      );
      expect(
        result.primary?.executionWindow?.startsAt,
        DateTime(2026, 9, 14, 13),
      );
      expect(
        result.primary?.executionWindow?.endsAt,
        DateTime(2026, 9, 14, 14, 30),
      );
    },
  );

  test(
    'uses the current deterministic schedule proposal before raw free time',
    () {
      final candidate = task(id: 'candidate', title: 'Draft brief');
      final proposal = DayScheduleProposal(
        date: DateTime(2026, 9, 14),
        freeMinutes: 240,
        acceptedMinutes: 0,
        proposedMinutes: 60,
        proposals: [
          ScheduleProposal(
            id: 'proposal',
            taskId: 'candidate',
            title: 'Draft brief',
            startsAt: DateTime(2026, 9, 14, 12),
            endsAt: DateTime(2026, 9, 14, 13),
            reason: 'Fits before the next commitment',
            score: 100,
            assumedEffort: false,
          ),
        ],
        unscheduledTaskCount: 0,
        assumedEffortCount: 0,
      );
      final state = scheduling([
        AvailabilitySlot(
          startsAt: DateTime(2026, 9, 14, 11),
          endsAt: DateTime(2026, 9, 14, 15),
        ),
      ], proposal: proposal);

      final result = engine.reason(
        now: now,
        tasks: [candidate],
        projects: const [],
        blocks: const [],
        scheduling: state,
      );

      expect(
        result.primary?.executionWindow?.kind,
        ContextualExecutionWindowKind.scheduleProposal,
      );
      expect(
        result.primary?.executionWindow?.startsAt,
        DateTime(2026, 9, 14, 12),
      );
      expect(result.primary?.reasons.join(' '), contains('Schedule proposal'));
    },
  );

  test('prefers a deterministic replanning recovery window', () {
    final candidate = task(id: 'candidate', title: 'Fix deck');
    final accepted = block(
      id: 'old',
      taskId: 'candidate',
      startsAt: DateTime(2026, 9, 14, 15),
    );
    final replanning = ReplanningOverview(
      generatedAt: now,
      horizonEnd: DateTime(2026, 9, 20),
      calendarConflictsChecked: true,
      issues: [
        ReplanningIssue(
          id: 'conflict',
          kind: ReplanningIssueKind.calendarConflict,
          title: 'Conflict',
          message: 'Move it',
          taskId: 'candidate',
          block: accepted,
          suggestion: ReplanningSuggestion(
            startsAt: DateTime(2026, 9, 14, 16),
            endsAt: DateTime(2026, 9, 14, 17),
          ),
        ),
      ],
    );

    final result = engine.reason(
      now: now,
      tasks: [candidate],
      projects: const [],
      blocks: [accepted],
      replanning: replanning,
    );

    expect(
      result.primary?.executionWindow?.kind,
      ContextualExecutionWindowKind.replanningSuggestion,
    );
    expect(
      result.primary?.executionWindow?.startsAt,
      DateTime(2026, 9, 14, 16),
    );
  });

  test(
    'carries explicit Personal Graph context without inferring new facts',
    () {
      final candidate = task(
        id: 'candidate',
        title: 'Prepare review',
        projectId: 'project',
      );
      final launch = project(deadline: DateTime(2026, 9, 20));
      final taskNode = PersonalGraphNode(
        id: PersonalGraph.nodeId(PersonalGraphNodeType.task, 'candidate'),
        type: PersonalGraphNodeType.task,
        entityId: 'candidate',
        label: 'Prepare review',
      );
      final projectNode = PersonalGraphNode(
        id: PersonalGraph.nodeId(PersonalGraphNodeType.project, 'project'),
        type: PersonalGraphNodeType.project,
        entityId: 'project',
        label: 'Launch',
      );
      final personNode = PersonalGraphNode(
        id: PersonalGraph.nodeId(PersonalGraphNodeType.person, 'sarah'),
        type: PersonalGraphNodeType.person,
        entityId: 'sarah',
        label: 'Sarah',
      );
      final eventNode = PersonalGraphNode(
        id: PersonalGraph.nodeId(PersonalGraphNodeType.event, 'event'),
        type: PersonalGraphNodeType.event,
        entityId: 'event',
        label: 'Architecture review',
        startsAt: DateTime(2026, 9, 16),
      );
      final decisionNode = PersonalGraphNode(
        id: PersonalGraph.nodeId(PersonalGraphNodeType.decision, 'decision'),
        type: PersonalGraphNodeType.decision,
        entityId: 'decision',
        label: 'Use Flutter',
      );
      final graph = PersonalGraph(
        nodes: {
          taskNode.id: taskNode,
          projectNode.id: projectNode,
          personNode.id: personNode,
          eventNode.id: eventNode,
          decisionNode.id: decisionNode,
        },
        edges: [
          PersonalGraphEdge(
            id: 'task-person',
            fromNodeId: taskNode.id,
            toNodeId: personNode.id,
            type: PersonalGraphEdgeType.involvesPerson,
          ),
          PersonalGraphEdge(
            id: 'task-project',
            fromNodeId: taskNode.id,
            toNodeId: projectNode.id,
            type: PersonalGraphEdgeType.belongsToProject,
          ),
          PersonalGraphEdge(
            id: 'event-project',
            fromNodeId: eventNode.id,
            toNodeId: projectNode.id,
            type: PersonalGraphEdgeType.relatesToProject,
          ),
          PersonalGraphEdge(
            id: 'decision-project',
            fromNodeId: decisionNode.id,
            toNodeId: projectNode.id,
            type: PersonalGraphEdgeType.belongsToProject,
          ),
        ],
      );

      final result = engine.reason(
        now: now,
        tasks: [candidate],
        projects: [launch],
        blocks: const [],
        personalGraph: graph,
      );

      expect(result.primary?.people, ['Sarah']);
      expect(result.primary?.relatedEvents, ['Architecture review']);
      expect(result.primary?.relatedDecisionCount, 1);
      expect(
        result.primary?.reasons.join(' '),
        contains('Architecture review'),
      );
    },
  );
}
