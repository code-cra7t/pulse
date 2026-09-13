import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/personal_graph/data/personal_graph_builder.dart';
import 'package:pulse/features/personal_graph/models/personal_graph.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const builder = PersonalGraphBuilder();
  final created = DateTime(2026, 9, 13, 8);

  test('builds typed relationships from existing JotCue sources', () {
    final note = _note(id: 'note-1', title: 'Exam prep', created: created);
    final project = _project(id: 'project-1', created: created);
    final task = _task(
      id: 'task-1',
      noteId: note.id,
      projectId: project.id,
      dueAt: DateTime(2026, 9, 20, 23, 59),
    );
    final block = _block(
      id: 'block-1',
      taskId: task.id,
      projectId: project.id,
      startsAt: DateTime(2026, 9, 15, 10),
    );

    final graph = builder.build(
      notes: [note],
      tasks: [task],
      projects: [project],
      scheduleBlocks: [block],
    );

    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.note,
      ),
      hasLength(1),
    );
    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.task,
      ),
      hasLength(1),
    );
    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.project,
      ),
      hasLength(1),
    );
    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.deadline,
      ),
      hasLength(2),
    );
    expect(
      graph.nodes.values.where(
        (node) => node.type == PersonalGraphNodeType.scheduleBlock,
      ),
      hasLength(1),
    );

    final context = graph.taskContext(task.id)!;
    expect(context.sourceNote?.entityId, note.id);
    expect(context.project?.entityId, project.id);
    expect(context.deadline?.startsAt, task.dueAt);
    expect(context.scheduleBlocks.single.entityId, block.id);
    expect(context.integrityIssues, isEmpty);
  });

  test('uses stable namespaced node and edge ids', () {
    final note = _note(id: 'same-id', title: 'Source', created: created);
    final task = _task(id: 'same-id', noteId: note.id);

    final graph = builder.build(
      notes: [note],
      tasks: [task],
      projects: const [],
      scheduleBlocks: const [],
    );

    final noteId = PersonalGraph.nodeId(PersonalGraphNodeType.note, 'same-id');
    final taskId = PersonalGraph.nodeId(PersonalGraphNodeType.task, 'same-id');
    expect(noteId, isNot(taskId));
    expect(graph.nodes[noteId]?.type, PersonalGraphNodeType.note);
    expect(graph.nodes[taskId]?.type, PersonalGraphNodeType.task);
    expect(graph.edges.single.id, contains('originatedFromNote'));
  });

  test(
    'records dangling note and project references instead of inventing nodes',
    () {
      final task = _task(
        id: 'task-1',
        noteId: 'missing-note',
        projectId: 'missing-project',
      );

      final graph = builder.build(
        notes: const [],
        tasks: [task],
        projects: const [],
        scheduleBlocks: const [],
      );

      expect(
        graph.nodes.values.where(
          (node) => node.type == PersonalGraphNodeType.note,
        ),
        isEmpty,
      );
      expect(
        graph.nodes.values.where(
          (node) => node.type == PersonalGraphNodeType.project,
        ),
        isEmpty,
      );
      expect(
        graph.integrityIssues.map((issue) => issue.type),
        containsAll([
          PersonalGraphIntegrityIssueType.missingSourceNote,
          PersonalGraphIntegrityIssueType.missingProject,
        ]),
      );
      expect(graph.taskContext(task.id)?.integrityIssues, hasLength(2));
    },
  );

  test(
    'records orphaned schedule blocks while preserving their local node',
    () {
      final block = _block(
        id: 'block-1',
        taskId: 'missing-task',
        startsAt: DateTime(2026, 9, 15, 10),
      );

      final graph = builder.build(
        notes: const [],
        tasks: const [],
        projects: const [],
        scheduleBlocks: [block],
      );

      expect(
        graph.node(PersonalGraphNodeType.scheduleBlock, block.id),
        isNotNull,
      );
      expect(
        graph.integrityIssues.single.type,
        PersonalGraphIntegrityIssueType.missingTaskForScheduleBlock,
      );
      expect(graph.edges, isEmpty);
    },
  );

  test('falls back to note content when a note title is absent', () {
    final note = Note(
      id: 'note-1',
      userId: 'user-1',
      title: null,
      isPinned: false,
      createdAt: created,
      updatedAt: created,
      tags: const [],
      content: '\n  First useful line  \nsecond',
      color: 0,
      images: const [],
    );

    final graph = builder.build(
      notes: [note],
      tasks: const [],
      projects: const [],
      scheduleBlocks: const [],
    );

    expect(
      graph.node(PersonalGraphNodeType.note, note.id)?.label,
      'First useful line',
    );
  });

  test('sorts schedule relationships and selects the next active block', () {
    final note = _note(id: 'note-1', title: 'Source', created: created);
    final task = _task(id: 'task-1', noteId: note.id);
    final completed = _block(
      id: 'completed',
      taskId: task.id,
      startsAt: DateTime(2026, 9, 13, 8),
      status: ScheduleBlockStatus.completed,
    );
    final later = _block(
      id: 'later',
      taskId: task.id,
      startsAt: DateTime(2026, 9, 13, 15),
    );
    final next = _block(
      id: 'next',
      taskId: task.id,
      startsAt: DateTime(2026, 9, 13, 12),
    );

    final context = builder
        .build(
          notes: [note],
          tasks: [task],
          projects: const [],
          scheduleBlocks: [later, completed, next],
        )
        .taskContext(task.id)!;

    expect(context.scheduleBlocks.map((node) => node.entityId), [
      'completed',
      'next',
      'later',
    ]);
    expect(
      context.nextScheduleBlock(DateTime(2026, 9, 13, 10))?.entityId,
      'next',
    );
  });
}

Note _note({
  required String id,
  required String title,
  required DateTime created,
}) {
  return Note(
    id: id,
    userId: 'user-1',
    title: title,
    isPinned: false,
    createdAt: created,
    updatedAt: created,
    tags: const [],
    content: 'content',
    color: 0,
    images: const [],
  );
}

Task _task({
  required String id,
  required String noteId,
  String? projectId,
  DateTime? dueAt,
}) {
  return Task(
    id: id,
    userId: 'user-1',
    title: 'Study graph theory',
    isCompleted: false,
    sourceNoteId: noteId,
    sourceLineIndex: 0,
    projectId: projectId,
    dueAt: dueAt,
    priority: PriorityLevel.high,
    estimatedMinutes: 60,
  );
}

Project _project({required String id, required DateTime created}) {
  return Project(
    id: id,
    userId: 'user-1',
    name: 'September exam',
    createdAt: created,
    updatedAt: created,
    deadline: DateTime(2026, 9, 22, 23, 59),
  );
}

ScheduleBlock _block({
  required String id,
  required String taskId,
  String? projectId,
  required DateTime startsAt,
  ScheduleBlockStatus status = ScheduleBlockStatus.scheduled,
}) {
  return ScheduleBlock(
    id: id,
    userId: 'user-1',
    taskId: taskId,
    title: 'Study graph theory',
    projectId: projectId,
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 1)),
    status: status,
    createdAt: startsAt.subtract(const Duration(days: 1)),
    updatedAt: startsAt.subtract(const Duration(days: 1)),
  );
}
