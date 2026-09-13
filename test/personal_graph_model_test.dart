import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/personal_graph/models/personal_graph.dart';

void main() {
  test('outgoing and incoming queries filter by edge type', () {
    const task = PersonalGraphNode(
      id: 'task:t1',
      type: PersonalGraphNodeType.task,
      entityId: 't1',
      label: 'Task',
    );
    const note = PersonalGraphNode(
      id: 'note:n1',
      type: PersonalGraphNodeType.note,
      entityId: 'n1',
      label: 'Note',
    );
    const project = PersonalGraphNode(
      id: 'project:p1',
      type: PersonalGraphNodeType.project,
      entityId: 'p1',
      label: 'Project',
    );
    const graph = PersonalGraph(
      nodes: {'task:t1': task, 'note:n1': note, 'project:p1': project},
      edges: [
        PersonalGraphEdge(
          id: 'e1',
          fromNodeId: 'task:t1',
          toNodeId: 'note:n1',
          type: PersonalGraphEdgeType.originatedFromNote,
        ),
        PersonalGraphEdge(
          id: 'e2',
          fromNodeId: 'task:t1',
          toNodeId: 'project:p1',
          type: PersonalGraphEdgeType.belongsToProject,
        ),
      ],
    );

    expect(
      graph
          .outgoing(task.id, type: PersonalGraphEdgeType.belongsToProject)
          .single
          .toNodeId,
      project.id,
    );
    expect(graph.incoming(note.id).single.fromNodeId, task.id);
  });

  test('taskContext returns null for unknown tasks', () {
    const graph = PersonalGraph(nodes: {}, edges: []);
    expect(graph.taskContext('missing'), isNull);
  });
}
