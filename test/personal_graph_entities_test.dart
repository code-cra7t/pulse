import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/personal_graph/data/personal_graph_builder.dart';
import 'package:pulse/features/personal_graph/models/personal_graph.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const builder = PersonalGraphBuilder();
  final created = DateTime(2026, 9, 14, 9);

  test('derives explicit people, decisions, events, and project relations', () {
    final note = _note(
      id: 'note-1',
      created: created,
      content: '''
People: Sarah Jones, Michael Chen
Decision: Use Flutter for the client app
Event: 2026-09-18 | Architecture review
''',
    );
    final project = _project('project-1', 'STG App', created);
    final task = _task('task-1', note.id, project.id);

    final graph = builder.build(
      notes: [note],
      tasks: [task],
      projects: [project],
      scheduleBlocks: const [],
    );

    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.person,
      ),
      hasLength(2),
    );
    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.decision,
      ),
      hasLength(1),
    );
    final event = graph.nodes.values.singleWhere(
      (node) => node.type == PersonalGraphNodeType.event,
    );
    expect(event.label, 'Architecture review');
    expect(event.startsAt, DateTime(2026, 9, 18));

    final noteNodeId = PersonalGraph.nodeId(
      PersonalGraphNodeType.note,
      note.id,
    );
    expect(
      graph.outgoing(noteNodeId, type: PersonalGraphEdgeType.referencesPerson),
      hasLength(2),
    );
    expect(
      graph.outgoing(noteNodeId, type: PersonalGraphEdgeType.recordsDecision),
      hasLength(1),
    );
    expect(
      graph.outgoing(noteNodeId, type: PersonalGraphEdgeType.recordsEvent),
      hasLength(1),
    );

    final taskContext = graph.taskContext(task.id)!;
    expect(taskContext.people.map((node) => node.label), [
      'Michael Chen',
      'Sarah Jones',
    ]);

    final projectNodeId = PersonalGraph.nodeId(
      PersonalGraphNodeType.project,
      project.id,
    );
    expect(
      graph.outgoing(projectNodeId, type: PersonalGraphEdgeType.involvesPerson),
      hasLength(2),
    );

    final decision = graph.nodes.values.singleWhere(
      (node) => node.type == PersonalGraphNodeType.decision,
    );
    expect(
      graph
          .outgoing(decision.id, type: PersonalGraphEdgeType.belongsToProject)
          .single
          .toNodeId,
      projectNodeId,
    );
    expect(
      graph
          .outgoing(event.id, type: PersonalGraphEdgeType.relatesToProject)
          .single
          .toNodeId,
      projectNodeId,
    );
    expect(
      graph.outgoing(event.id, type: PersonalGraphEdgeType.involvesPerson),
      hasLength(2),
    );
  });

  test(
    'does not guess a project for note facts spanning multiple projects',
    () {
      final note = _note(
        id: 'note-1',
        created: created,
        content: '''
Decision: Keep both workstreams separate
Event: Joint review
''',
      );
      final first = _project('project-1', 'STG App', created);
      final second = _project('project-2', 'JotCue', created);

      final graph = builder.build(
        notes: [note],
        tasks: [
          _task('task-1', note.id, first.id),
          _task('task-2', note.id, second.id),
        ],
        projects: [first, second],
        scheduleBlocks: const [],
      );

      final decision = graph.nodes.values.singleWhere(
        (node) => node.type == PersonalGraphNodeType.decision,
      );
      final event = graph.nodes.values.singleWhere(
        (node) => node.type == PersonalGraphNodeType.event,
      );

      expect(
        graph.outgoing(
          decision.id,
          type: PersonalGraphEdgeType.belongsToProject,
        ),
        isEmpty,
      );
      expect(
        graph.outgoing(event.id, type: PersonalGraphEdgeType.relatesToProject),
        isEmpty,
      );
    },
  );
}

Note _note({
  required String id,
  required DateTime created,
  required String content,
}) {
  return Note(
    id: id,
    userId: 'user-1',
    title: 'Graph facts',
    isPinned: false,
    createdAt: created,
    updatedAt: created,
    tags: const [],
    content: content,
    color: 0,
    images: const [],
  );
}

Project _project(String id, String name, DateTime created) {
  return Project(
    id: id,
    userId: 'user-1',
    name: name,
    createdAt: created,
    updatedAt: created,
  );
}

Task _task(String id, String noteId, String projectId) {
  return Task(
    id: id,
    userId: 'user-1',
    title: 'Work item',
    isCompleted: false,
    sourceNoteId: noteId,
    sourceLineIndex: 0,
    projectId: projectId,
    priority: PriorityLevel.medium,
  );
}
