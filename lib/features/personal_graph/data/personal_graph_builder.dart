import '../../notes/models/note.dart';
import '../../projects/models/project.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../models/personal_graph.dart';
import 'explicit_graph_fact_parser.dart';

class PersonalGraphBuilder {
  const PersonalGraphBuilder();

  static const _factParser = ExplicitGraphFactParser();

  PersonalGraph build({
    required List<Note> notes,
    required List<Task> tasks,
    required List<Project> projects,
    required List<ScheduleBlock> scheduleBlocks,
  }) {
    final nodes = <String, PersonalGraphNode>{};
    final edges = <PersonalGraphEdge>[];
    final issues = <PersonalGraphIntegrityIssue>[];

    final noteById = {for (final note in notes) note.id: note};
    final taskById = {for (final task in tasks) task.id: task};
    final projectById = {for (final project in projects) project.id: project};
    final factsByNoteId = {
      for (final note in notes) note.id: _factParser.parse(note),
    };
    final projectIdsByNote = <String, Set<String>>{};
    for (final task in tasks) {
      final projectId = task.projectId;
      if (task.sourceNoteId.isEmpty ||
          projectId == null ||
          projectId.isEmpty ||
          !projectById.containsKey(projectId)) {
        continue;
      }
      projectIdsByNote
          .putIfAbsent(task.sourceNoteId, () => <String>{})
          .add(projectId);
    }

    for (final note in notes) {
      _putNode(
        nodes,
        PersonalGraphNode(
          id: PersonalGraph.nodeId(PersonalGraphNodeType.note, note.id),
          type: PersonalGraphNodeType.note,
          entityId: note.id,
          label: _noteLabel(note),
        ),
      );

      final facts = factsByNoteId[note.id]!;
      final noteNodeId = PersonalGraph.nodeId(
        PersonalGraphNodeType.note,
        note.id,
      );

      for (final person in facts.people) {
        final personNode = PersonalGraphNode(
          id: PersonalGraph.nodeId(
            PersonalGraphNodeType.person,
            person.entityId,
          ),
          type: PersonalGraphNodeType.person,
          entityId: person.entityId,
          label: person.label,
        );
        _putNode(nodes, personNode);
        _addUniqueEdge(
          edges,
          _edge(
            fromNodeId: noteNodeId,
            toNodeId: personNode.id,
            type: PersonalGraphEdgeType.referencesPerson,
          ),
        );
      }

      for (final decision in facts.decisions) {
        final decisionNode = PersonalGraphNode(
          id: PersonalGraph.nodeId(
            PersonalGraphNodeType.decision,
            decision.entityId,
          ),
          type: PersonalGraphNodeType.decision,
          entityId: decision.entityId,
          label: decision.label,
        );
        _putNode(nodes, decisionNode);
        _addUniqueEdge(
          edges,
          _edge(
            fromNodeId: noteNodeId,
            toNodeId: decisionNode.id,
            type: PersonalGraphEdgeType.recordsDecision,
          ),
        );
      }

      for (final event in facts.events) {
        final eventNode = PersonalGraphNode(
          id: PersonalGraph.nodeId(PersonalGraphNodeType.event, event.entityId),
          type: PersonalGraphNodeType.event,
          entityId: event.entityId,
          label: event.label,
          startsAt: event.startsAt,
        );
        _putNode(nodes, eventNode);
        _addUniqueEdge(
          edges,
          _edge(
            fromNodeId: noteNodeId,
            toNodeId: eventNode.id,
            type: PersonalGraphEdgeType.recordsEvent,
          ),
        );
        for (final person in facts.people) {
          _addUniqueEdge(
            edges,
            _edge(
              fromNodeId: eventNode.id,
              toNodeId: PersonalGraph.nodeId(
                PersonalGraphNodeType.person,
                person.entityId,
              ),
              type: PersonalGraphEdgeType.involvesPerson,
            ),
          );
        }
      }
    }

    for (final project in projects) {
      final projectNodeId = PersonalGraph.nodeId(
        PersonalGraphNodeType.project,
        project.id,
      );
      _putNode(
        nodes,
        PersonalGraphNode(
          id: projectNodeId,
          type: PersonalGraphNodeType.project,
          entityId: project.id,
          label: project.name,
          isCompleted: project.status == ProjectStatus.completed,
          status: project.status.name,
        ),
      );
      final deadline = project.deadline;
      if (deadline != null) {
        final deadlineNode = _deadlineNode(
          ownerType: PersonalGraphNodeType.project,
          ownerId: project.id,
          ownerLabel: project.name,
          dueAt: deadline,
        );
        _putNode(nodes, deadlineNode);
        edges.add(
          _edge(
            fromNodeId: projectNodeId,
            toNodeId: deadlineNode.id,
            type: PersonalGraphEdgeType.hasDeadline,
          ),
        );
      }
    }

    for (final task in tasks) {
      _putNode(
        nodes,
        PersonalGraphNode(
          id: PersonalGraph.nodeId(PersonalGraphNodeType.task, task.id),
          type: PersonalGraphNodeType.task,
          entityId: task.id,
          label: task.title,
          isCompleted: task.isCompleted,
        ),
      );
    }

    for (final task in tasks) {
      final taskNodeId = PersonalGraph.nodeId(
        PersonalGraphNodeType.task,
        task.id,
      );

      final sourceNote = noteById[task.sourceNoteId];
      if (sourceNote != null) {
        edges.add(
          _edge(
            fromNodeId: taskNodeId,
            toNodeId: PersonalGraph.nodeId(
              PersonalGraphNodeType.note,
              sourceNote.id,
            ),
            type: PersonalGraphEdgeType.originatedFromNote,
          ),
        );
      } else if (task.sourceNoteId.isNotEmpty) {
        issues.add(
          PersonalGraphIntegrityIssue(
            type: PersonalGraphIntegrityIssueType.missingSourceNote,
            entityId: task.id,
            missingReferenceId: task.sourceNoteId,
          ),
        );
      }

      final sourceFacts = factsByNoteId[task.sourceNoteId];
      if (sourceFacts != null) {
        for (final person in sourceFacts.people) {
          _addUniqueEdge(
            edges,
            _edge(
              fromNodeId: taskNodeId,
              toNodeId: PersonalGraph.nodeId(
                PersonalGraphNodeType.person,
                person.entityId,
              ),
              type: PersonalGraphEdgeType.involvesPerson,
            ),
          );
        }
      }

      final projectId = task.projectId;
      if (projectId != null && projectId.isNotEmpty) {
        if (projectById.containsKey(projectId)) {
          edges.add(
            _edge(
              fromNodeId: taskNodeId,
              toNodeId: PersonalGraph.nodeId(
                PersonalGraphNodeType.project,
                projectId,
              ),
              type: PersonalGraphEdgeType.belongsToProject,
            ),
          );
        } else {
          issues.add(
            PersonalGraphIntegrityIssue(
              type: PersonalGraphIntegrityIssueType.missingProject,
              entityId: task.id,
              missingReferenceId: projectId,
            ),
          );
        }
      }

      for (final dependencyId in task.dependsOnTaskIds) {
        if (taskById.containsKey(dependencyId)) {
          edges.add(
            _edge(
              fromNodeId: taskNodeId,
              toNodeId: PersonalGraph.nodeId(
                PersonalGraphNodeType.task,
                dependencyId,
              ),
              type: PersonalGraphEdgeType.dependsOnTask,
            ),
          );
        } else {
          issues.add(
            PersonalGraphIntegrityIssue(
              type: PersonalGraphIntegrityIssueType.missingDependencyTask,
              entityId: task.id,
              missingReferenceId: dependencyId,
            ),
          );
        }
      }

      final dueAt = task.dueAt;
      if (dueAt != null) {
        final deadlineNode = _deadlineNode(
          ownerType: PersonalGraphNodeType.task,
          ownerId: task.id,
          ownerLabel: task.title,
          dueAt: dueAt,
        );
        _putNode(nodes, deadlineNode);
        edges.add(
          _edge(
            fromNodeId: taskNodeId,
            toNodeId: deadlineNode.id,
            type: PersonalGraphEdgeType.hasDeadline,
          ),
        );
      }
    }

    for (final note in notes) {
      final projectIds = projectIdsByNote[note.id];
      if (projectIds == null || projectIds.length != 1) continue;

      final projectId = projectIds.single;
      final projectNodeId = PersonalGraph.nodeId(
        PersonalGraphNodeType.project,
        projectId,
      );
      final facts = factsByNoteId[note.id]!;

      for (final person in facts.people) {
        _addUniqueEdge(
          edges,
          _edge(
            fromNodeId: projectNodeId,
            toNodeId: PersonalGraph.nodeId(
              PersonalGraphNodeType.person,
              person.entityId,
            ),
            type: PersonalGraphEdgeType.involvesPerson,
          ),
        );
      }

      for (final decision in facts.decisions) {
        _addUniqueEdge(
          edges,
          _edge(
            fromNodeId: PersonalGraph.nodeId(
              PersonalGraphNodeType.decision,
              decision.entityId,
            ),
            toNodeId: projectNodeId,
            type: PersonalGraphEdgeType.belongsToProject,
          ),
        );
      }

      for (final event in facts.events) {
        _addUniqueEdge(
          edges,
          _edge(
            fromNodeId: PersonalGraph.nodeId(
              PersonalGraphNodeType.event,
              event.entityId,
            ),
            toNodeId: projectNodeId,
            type: PersonalGraphEdgeType.relatesToProject,
          ),
        );
      }
    }

    for (final block in scheduleBlocks) {
      final blockNode = PersonalGraphNode(
        id: PersonalGraph.nodeId(PersonalGraphNodeType.scheduleBlock, block.id),
        type: PersonalGraphNodeType.scheduleBlock,
        entityId: block.id,
        label: block.title,
        startsAt: block.startsAt,
        endsAt: block.endsAt,
        isCompleted: block.status == ScheduleBlockStatus.completed,
        status: block.status.name,
      );
      _putNode(nodes, blockNode);

      final task = taskById[block.taskId];
      if (task != null) {
        edges.add(
          _edge(
            fromNodeId: PersonalGraph.nodeId(
              PersonalGraphNodeType.task,
              task.id,
            ),
            toNodeId: blockNode.id,
            type: PersonalGraphEdgeType.scheduledAs,
          ),
        );
      } else if (block.taskId.isNotEmpty) {
        issues.add(
          PersonalGraphIntegrityIssue(
            type: PersonalGraphIntegrityIssueType.missingTaskForScheduleBlock,
            entityId: block.id,
            missingReferenceId: block.taskId,
          ),
        );
      }
    }

    return PersonalGraph(
      nodes: Map<String, PersonalGraphNode>.unmodifiable(nodes),
      edges: List<PersonalGraphEdge>.unmodifiable(edges),
      integrityIssues: List<PersonalGraphIntegrityIssue>.unmodifiable(issues),
    );
  }

  void _putNode(Map<String, PersonalGraphNode> nodes, PersonalGraphNode node) {
    nodes[node.id] = node;
  }

  void _addUniqueEdge(List<PersonalGraphEdge> edges, PersonalGraphEdge edge) {
    if (edges.any((existing) => existing.id == edge.id)) return;
    edges.add(edge);
  }

  PersonalGraphNode _deadlineNode({
    required PersonalGraphNodeType ownerType,
    required String ownerId,
    required String ownerLabel,
    required DateTime dueAt,
  }) {
    final entityId = '${ownerType.name}:$ownerId';
    return PersonalGraphNode(
      id: PersonalGraph.nodeId(PersonalGraphNodeType.deadline, entityId),
      type: PersonalGraphNodeType.deadline,
      entityId: entityId,
      label: '$ownerLabel deadline',
      startsAt: dueAt,
    );
  }

  PersonalGraphEdge _edge({
    required String fromNodeId,
    required String toNodeId,
    required PersonalGraphEdgeType type,
  }) {
    return PersonalGraphEdge(
      id: '${type.name}:$fromNodeId->$toNodeId',
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      type: type,
    );
  }

  String _noteLabel(Note note) {
    final title = note.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final firstLine = note.content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Untitled note');
    return firstLine.length <= 60
        ? firstLine
        : '${firstLine.substring(0, 57)}...';
  }
}
