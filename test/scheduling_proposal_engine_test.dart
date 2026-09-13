import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/calendar/models/availability_summary.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/scheduling/data/scheduling_proposal_engine.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const engine = SchedulingProposalEngine();
  final day = DateTime(2026, 9, 14);
  final now = DateTime(2026, 9, 14, 8);
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  SchedulingPreferences preferences({
    int preferred = 90,
    int maxDaily = 360,
    int defaultTask = 30,
    int breakMinutes = 15,
  }) {
    return SchedulingPreferences.defaults().copyWith(
      isConfigured: true,
      availableWeekdays: const [DateTime.monday],
      minimumBlockMinutes: 30,
      preferredBlockMinutes: preferred,
      maxFocusMinutesPerDay: maxDaily,
      defaultTaskMinutes: defaultTask,
      breakMinutes: breakMinutes,
    );
  }

  AvailabilitySummary availability(List<(DateTime, DateTime)> slots) {
    final free = slots.fold<int>(
      0,
      (sum, slot) => sum + slot.$2.difference(slot.$1).inMinutes,
    );
    return AvailabilitySummary(
      windowStart: at(8),
      windowEnd: at(20),
      busyMinutes: 720 - free,
      freeMinutes: free,
      freeSlots: slots
          .map((slot) => AvailabilitySlot(startsAt: slot.$1, endsAt: slot.$2))
          .toList(),
    );
  }

  test('higher urgency task gets the earliest available slot', () {
    final result = engine.build(
      now: now,
      date: day,
      preferences: preferences(preferred: 60, breakMinutes: 0),
      availability: availability([(at(9), at(12))]),
      tasks: [
        _task('routine', title: 'Routine', estimate: 60),
        _task(
          'urgent',
          title: 'Urgent',
          estimate: 60,
          priority: PriorityLevel.critical,
          dueAt: at(18),
        ),
      ],
      projects: const [],
      existingBlocks: const [],
    );

    expect(result.proposals.first.taskId, 'urgent');
    expect(result.proposals.first.startsAt, at(9));
  });

  test('splits large flexible work into preferred sessions with breaks', () {
    final result = engine.build(
      now: now,
      date: day,
      preferences: preferences(preferred: 90, breakMinutes: 15),
      availability: availability([(at(9), at(13))]),
      tasks: [_task('hpc', title: 'HPC', estimate: 180)],
      projects: const [],
      existingBlocks: const [],
    );

    expect(result.proposals, hasLength(2));
    expect(result.proposals[0].minutes, 90);
    expect(result.proposals[0].startsAt, at(9));
    expect(result.proposals[1].startsAt, at(10, 45));
  });

  test('daily focus cap subtracts already accepted blocks', () {
    final accepted = ScheduleBlock(
      id: 'accepted',
      userId: 'user',
      taskId: 'other',
      title: 'Already planned',
      startsAt: at(9),
      endsAt: at(10),
      createdAt: now,
      updatedAt: now,
    );
    final result = engine.build(
      now: now,
      date: day,
      preferences: preferences(preferred: 90, maxDaily: 120, breakMinutes: 0),
      availability: availability([(at(10), at(14))]),
      tasks: [_task('next', title: 'Next', estimate: 120)],
      projects: const [],
      existingBlocks: [accepted],
    );

    expect(result.acceptedMinutes, 60);
    expect(result.proposedMinutes, 60);
  });

  test('existing future blocks reduce remaining effort for the same task', () {
    final accepted = ScheduleBlock(
      id: 'accepted',
      userId: 'user',
      taskId: 'exam',
      title: 'Exam prep',
      startsAt: at(15),
      endsAt: at(16),
      createdAt: now,
      updatedAt: now,
    );
    final result = engine.build(
      now: now,
      date: day,
      preferences: preferences(preferred: 90, breakMinutes: 0),
      availability: availability([(at(9), at(12))]),
      tasks: [_task('exam', title: 'Exam prep', estimate: 120)],
      projects: const [],
      existingBlocks: [accepted],
    );

    expect(result.proposedMinutes, 60);
  });

  test(
    'unestimated tasks use the explicit default duration and are labelled',
    () {
      final result = engine.build(
        now: now,
        date: day,
        preferences: preferences(defaultTask: 45, breakMinutes: 0),
        availability: availability([(at(9), at(11))]),
        tasks: [_task('unknown', title: 'Unestimated')],
        projects: const [],
        existingBlocks: const [],
      );

      expect(result.proposals.single.minutes, 45);
      expect(result.proposals.single.assumedEffort, isTrue);
      expect(result.assumedEffortCount, 1);
    },
  );

  test(
    'non-flexible tasks may be proposed initially while paused projects stay out',
    () {
      final paused = Project(
        id: 'paused',
        userId: 'user',
        name: 'Paused project',
        status: ProjectStatus.paused,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 13),
      );
      final result = engine.build(
        now: now,
        date: day,
        preferences: preferences(),
        availability: availability([(at(9), at(13))]),
        tasks: [
          _task('fixed', title: 'Fixed', estimate: 60, flexible: false),
          _task(
            'paused-task',
            title: 'Paused task',
            estimate: 60,
            projectId: paused.id,
          ),
        ],
        projects: [paused],
        existingBlocks: const [],
      );

      expect(result.proposals.map((proposal) => proposal.taskId), ['fixed']);
    },
  );
}

Task _task(
  String id, {
  required String title,
  int? estimate,
  PriorityLevel priority = PriorityLevel.none,
  DateTime? dueAt,
  String? projectId,
  bool flexible = true,
}) {
  return Task(
    id: id,
    userId: 'user',
    title: title,
    isCompleted: false,
    sourceNoteId: 'note-$id',
    sourceLineIndex: 0,
    projectId: projectId,
    dueAt: dueAt,
    priority: priority,
    estimatedMinutes: estimate,
    isFlexible: flexible,
  );
}
