import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/tasks/data/task_dependency_analyzer.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  test('Pulse focus excludes blocked work but keeps open counts truthful', () {
    final gate = _task('gate', 'Wait for transcript');
    final blocked = _task('blocked', 'Submit', dependsOn: const ['gate']);
    final ready = _task('ready', 'Review essay');
    final tasks = [gate, blocked, ready];
    final dependencies = const TaskDependencyAnalyzer().analyze(tasks);
    final overview = PulseOverview.build(
      projects: const [],
      tasks: tasks,
      now: DateTime(2026, 9, 13, 12),
      dependencyAnalysis: dependencies,
    );
    expect(overview.openTaskCount, 3);
    expect(
      overview.focusItems.map((item) => item.task.id),
      isNot(contains('blocked')),
    );
  });
}

Task _task(String id, String title, {List<String> dependsOn = const []}) =>
    Task(
      id: id,
      userId: 'u',
      title: title,
      isCompleted: false,
      sourceNoteId: 'note-$id',
      sourceLineIndex: 0,
      dependsOnTaskIds: dependsOn,
    );
