enum PersonalGraphNodeType {
  note,
  task,
  project,
  deadline,
  scheduleBlock,
  person,
  decision,
  event,
}

enum PersonalGraphEdgeType {
  originatedFromNote,
  belongsToProject,
  hasDeadline,
  scheduledAs,
}

enum PersonalGraphIntegrityIssueType {
  missingSourceNote,
  missingProject,
  missingTaskForScheduleBlock,
}

class PersonalGraphNode {
  const PersonalGraphNode({
    required this.id,
    required this.type,
    required this.entityId,
    required this.label,
    this.startsAt,
    this.endsAt,
    this.isCompleted,
    this.status,
  });

  final String id;
  final PersonalGraphNodeType type;
  final String entityId;
  final String label;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool? isCompleted;
  final String? status;
}

class PersonalGraphEdge {
  const PersonalGraphEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.type,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final PersonalGraphEdgeType type;
}

class PersonalGraphIntegrityIssue {
  const PersonalGraphIntegrityIssue({
    required this.type,
    required this.entityId,
    required this.missingReferenceId,
  });

  final PersonalGraphIntegrityIssueType type;
  final String entityId;
  final String missingReferenceId;
}

class PersonalGraphTaskContext {
  const PersonalGraphTaskContext({
    required this.task,
    this.sourceNote,
    this.project,
    this.deadline,
    this.scheduleBlocks = const <PersonalGraphNode>[],
    this.integrityIssues = const <PersonalGraphIntegrityIssue>[],
  });

  final PersonalGraphNode task;
  final PersonalGraphNode? sourceNote;
  final PersonalGraphNode? project;
  final PersonalGraphNode? deadline;
  final List<PersonalGraphNode> scheduleBlocks;
  final List<PersonalGraphIntegrityIssue> integrityIssues;

  bool get hasRelatedContext =>
      sourceNote != null ||
      project != null ||
      deadline != null ||
      scheduleBlocks.isNotEmpty ||
      integrityIssues.isNotEmpty;

  PersonalGraphNode? nextScheduleBlock(DateTime now) {
    for (final block in scheduleBlocks) {
      if (block.status == 'scheduled' &&
          block.endsAt != null &&
          block.endsAt!.isAfter(now)) {
        return block;
      }
    }
    return null;
  }
}

class PersonalGraph {
  const PersonalGraph({
    required this.nodes,
    required this.edges,
    this.integrityIssues = const <PersonalGraphIntegrityIssue>[],
  });

  final Map<String, PersonalGraphNode> nodes;
  final List<PersonalGraphEdge> edges;
  final List<PersonalGraphIntegrityIssue> integrityIssues;

  static String nodeId(PersonalGraphNodeType type, String entityId) {
    return '${type.name}:$entityId';
  }

  PersonalGraphNode? node(PersonalGraphNodeType type, String entityId) {
    return nodes[nodeId(type, entityId)];
  }

  List<PersonalGraphEdge> outgoing(
    String nodeId, {
    PersonalGraphEdgeType? type,
  }) {
    return edges
        .where(
          (edge) =>
              edge.fromNodeId == nodeId && (type == null || edge.type == type),
        )
        .toList(growable: false);
  }

  List<PersonalGraphEdge> incoming(
    String nodeId, {
    PersonalGraphEdgeType? type,
  }) {
    return edges
        .where(
          (edge) =>
              edge.toNodeId == nodeId && (type == null || edge.type == type),
        )
        .toList(growable: false);
  }

  PersonalGraphTaskContext? taskContext(String taskId) {
    final taskNode = node(PersonalGraphNodeType.task, taskId);
    if (taskNode == null) return null;

    PersonalGraphNode? target(PersonalGraphEdgeType edgeType) {
      for (final edge in outgoing(taskNode.id, type: edgeType)) {
        final targetNode = nodes[edge.toNodeId];
        if (targetNode != null) return targetNode;
      }
      return null;
    }

    final scheduleNodes =
        outgoing(taskNode.id, type: PersonalGraphEdgeType.scheduledAs)
            .map((edge) => nodes[edge.toNodeId])
            .whereType<PersonalGraphNode>()
            .toList()
          ..sort((a, b) {
            final aStart = a.startsAt;
            final bStart = b.startsAt;
            if (aStart == null && bStart == null) {
              return a.label.compareTo(b.label);
            }
            if (aStart == null) return 1;
            if (bStart == null) return -1;
            return aStart.compareTo(bStart);
          });

    final taskIssues = integrityIssues
        .where((issue) => issue.entityId == taskId)
        .toList(growable: false);

    return PersonalGraphTaskContext(
      task: taskNode,
      sourceNote: target(PersonalGraphEdgeType.originatedFromNote),
      project: target(PersonalGraphEdgeType.belongsToProject),
      deadline: target(PersonalGraphEdgeType.hasDeadline),
      scheduleBlocks: scheduleNodes,
      integrityIssues: taskIssues,
    );
  }
}
