import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/personal_graph/data/personal_graph_builder.dart';
import 'package:pulse/features/personal_graph/models/personal_graph.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const builder = PersonalGraphBuilder();

  test('graph derives task dependency edges and task context', () {
    final prerequisite = _task('a', 'Research');
    final dependent = _task('b', 'Write', dependsOn: const ['a']);
    final graph = builder.build(
      notes: const [],
      tasks: [prerequisite, dependent],
      projects: const [],
      scheduleBlocks: const [],
    );
    final context = graph.taskContext('b')!;
    expect(context.prerequisiteTasks.single.entityId, 'a');
    expect(
      graph.outgoing(
        PersonalGraph.nodeId(PersonalGraphNodeType.task, 'b'),
        type: PersonalGraphEdgeType.dependsOnTask,
      ),
      hasLength(1),
    );
  });

  test('graph records missing dependency instead of inventing a task node', () {
    final dependent = _task('b', 'Write', dependsOn: const ['missing']);
    final graph = builder.build(
      notes: const [],
      tasks: [dependent],
      projects: const [],
      scheduleBlocks: const [],
    );
    expect(
      graph.integrityIssues.map((issue) => issue.type),
      contains(PersonalGraphIntegrityIssueType.missingDependencyTask),
    );
    expect(graph.node(PersonalGraphNodeType.task, 'missing'), isNull);
  });
}

Task _task(String id, String title, {List<String> dependsOn = const []}) =>
    Task(
      id: id,
      userId: 'u',
      title: title,
      isCompleted: false,
      sourceNoteId: '',
      sourceLineIndex: 0,
      dependsOnTaskIds: dependsOn,
    );
