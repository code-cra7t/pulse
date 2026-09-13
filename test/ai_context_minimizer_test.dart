import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/assistant/data/ai_context_minimizer.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  test('remote context excludes account and source-note identifiers', () {
    final now = DateTime(2026, 9, 13, 12);
    final task = Task(
      id: 'task-1',
      userId: 'secret-user-id',
      title: 'Submit scholarship application',
      isCompleted: false,
      sourceNoteId: 'secret-note-id',
      sourceLineIndex: 77,
      priority: PriorityLevel.high,
      waitingFor: 'private supervisor comment',
    );
    final project = Project(
      id: 'project-1',
      userId: 'secret-user-id',
      name: 'Scholarship',
      createdAt: now,
      updatedAt: now,
    );
    final block = ScheduleBlock(
      id: 'block-1',
      userId: 'secret-user-id',
      taskId: task.id,
      title: task.title,
      startsAt: now.add(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
      createdAt: now,
      updatedAt: now,
    );
    const pulse = PulseOverview(
      focusItems: [],
      cues: [],
      upcomingProjects: [],
      openTaskCount: 1,
      overdueCount: 0,
      dueTodayCount: 0,
      focusEstimatedMinutes: 0,
    );
    final context = AskJotCueContext(
      now: now,
      pulse: pulse,
      dailyLoop: DailyPulseLoop.build(now: now, pulse: pulse, blocks: [block]),
      tasks: [task],
      projects: [project],
      blocks: [block],
    );

    final json = jsonEncode(const AiContextMinimizer().build(context));
    expect(json, contains('Submit scholarship application'));
    expect(json, contains('Scholarship'));
    expect(json, isNot(contains('secret-user-id')));
    expect(json, isNot(contains('secret-note-id')));
    expect(json, isNot(contains('sourceNoteId')));
    expect(json, isNot(contains('sourceLineIndex')));
    expect(json, isNot(contains('private supervisor comment')));
    expect(json, contains('hasWaitingFor'));
  });
}
