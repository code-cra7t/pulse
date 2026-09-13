import '../../notes/models/note.dart';
import '../../projects/models/project.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../models/personal_graph.dart';

class PersonalGraphBuilder {
  const PersonalGraphBuilder();

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
      final taskNodeId = PersonalGraph.nodeId(
        PersonalGraphNodeType.task,
        task.id,
      );
      _putNode(
        nodes,
        PersonalGraphNode(
          id: taskNodeId,
          type: PersonalGraphNodeType.task,
          entityId: task.id,
          label: task.title,
          isCompleted: task.isCompleted,
        ),
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
