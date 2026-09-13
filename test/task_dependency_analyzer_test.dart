import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/tasks/data/task_dependency_analyzer.dart';
import 'package:pulse/features/tasks/models/task.dart';
import 'package:pulse/features/tasks/models/task_action_cue.dart';

void main() {
  const analyzer = TaskDependencyAnalyzer();

  test('task without blockers is ready', () {
    final task = _task('a', 'Draft');
    final result = analyzer.analyze([task]);
    expect(result.cueForTask('a')?.state, TaskActionState.ready);
  });

  test('incomplete prerequisite blocks dependent task', () {
    final prerequisite = _task('a', 'Research');
    final dependent = _task('b', 'Write', dependsOn: const ['a']);
    final cue = analyzer.analyze([prerequisite, dependent]).cueForTask('b')!;
    expect(cue.isBlocked, isTrue);
    expect(cue.shortLabel, 'Blocked by Research');
  });

  test('completed prerequisite satisfies dependency', () {
    final prerequisite = _task('a', 'Research', completed: true);
    final dependent = _task('b', 'Write', dependsOn: const ['a']);
    expect(
      analyzer.analyze([prerequisite, dependent]).cueForTask('b')?.isReady,
      isTrue,
    );
  });

  test('waiting-for text blocks until the user clears it', () {
    final task = _task('a', 'Submit', waitingFor: 'supervisor feedback');
    final cue = analyzer.analyze([task]).cueForTask('a')!;
    expect(cue.isBlocked, isTrue);
    expect(cue.shortLabel, 'Waiting for supervisor feedback');
  });

  test('missing dependency fails closed as blocked', () {
    final task = _task('a', 'Submit', dependsOn: const ['missing']);
    final cue = analyzer.analyze([task]).cueForTask('a')!;
    expect(cue.isBlocked, isTrue);
    expect(
      cue.blockers.map((blocker) => blocker.kind),
      contains(TaskBlockerKind.missingDependency),
    );
  });

  test('dependency cycles are detected and blocked', () {
    final a = _task('a', 'A', dependsOn: const ['b']);
    final b = _task('b', 'B', dependsOn: const ['a']);
    final result = analyzer.analyze([a, b]);
    expect(result.cycleTaskIds, containsAll(['a', 'b']));
    expect(result.cueForTask('a')?.isBlocked, isTrue);
    expect(result.cueForTask('b')?.isBlocked, isTrue);
  });

  test('project next action chooses the best ready task only', () {
    final blocked = _task(
      'blocked',
      'Blocked urgent',
      projectId: 'p',
      dependsOn: const ['gate'],
      dueAt: DateTime(2026, 9, 14),
      priority: PriorityLevel.critical,
    );
    final gate = _task('gate', 'Gate', projectId: 'other');
    final later = _task(
      'later',
      'Later',
      projectId: 'p',
      dueAt: DateTime(2026, 9, 20),
    );
    final sooner = _task(
      'sooner',
      'Sooner',
      projectId: 'p',
      dueAt: DateTime(2026, 9, 16),
    );
    final cue = analyzer
        .analyze([blocked, gate, later, sooner])
        .cueForProject('p')!;
    expect(cue.nextTask?.id, 'sooner');
    expect(cue.blockedCount, 1);
    expect(cue.openCount, 3);
  });
}

Task _task(
  String id,
  String title, {
  bool completed = false,
  String? projectId,
  List<String> dependsOn = const [],
  String? waitingFor,
  DateTime? dueAt,
  PriorityLevel priority = PriorityLevel.none,
}) {
  return Task(
    id: id,
    userId: 'u',
    title: title,
    isCompleted: completed,
    sourceNoteId: 'note-$id',
    sourceLineIndex: 0,
    projectId: projectId,
    dependsOnTaskIds: dependsOn,
    waitingFor: waitingFor,
    dueAt: dueAt,
    priority: priority,
  );
}
