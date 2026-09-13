import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/calendar/models/availability_summary.dart';
import 'package:pulse/features/calendar/models/calendar_busy_event.dart';
import 'package:pulse/features/scheduling/data/adaptive_replanning_engine.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  const engine = AdaptiveReplanningEngine();
  final now = DateTime(2026, 9, 14, 12);

  SchedulingPreferences preferences() {
    return SchedulingPreferences.defaults().copyWith(
      isConfigured: true,
      availableWeekdays: const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ],
      dayStartMinutes: 8 * 60,
      dayEndMinutes: 20 * 60,
      minimumBlockMinutes: 30,
      preferredBlockMinutes: 60,
      maxFocusMinutesPerDay: 240,
    );
  }

  test('past scheduled block is surfaced for review with a recovery slot', () {
    final block = _block(
      'past',
      DateTime(2026, 9, 14, 9),
      DateTime(2026, 9, 14, 10),
    );
    final result = engine.build(
      now: now,
      preferences: preferences(),
      blocks: [block],
      tasks: const [],
      projects: const [],
      calendarBusyEvents: const [],
      horizonAvailability: [
        _availability(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 20), [
          (DateTime(2026, 9, 14, 13), DateTime(2026, 9, 14, 15)),
        ]),
      ],
      calendarConflictsChecked: true,
    );

    expect(result.issues, hasLength(1));
    expect(result.issues.single.kind, ReplanningIssueKind.pastBlockReview);
    expect(
      result.issues.single.suggestion?.startsAt,
      DateTime(2026, 9, 14, 13),
    );
  });

  test('changed device calendar conflict proposes another free slot', () {
    final block = _block(
      'future',
      DateTime(2026, 9, 14, 14),
      DateTime(2026, 9, 14, 15),
    );
    final result = engine.build(
      now: now,
      preferences: preferences(),
      blocks: [block],
      tasks: const [],
      projects: const [],
      calendarBusyEvents: [
        CalendarBusyEvent(
          id: 'meeting',
          title: 'Meeting',
          startsAt: DateTime(2026, 9, 14, 14, 30),
          endsAt: DateTime(2026, 9, 14, 15, 30),
        ),
      ],
      horizonAvailability: [
        _availability(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 20), [
          (DateTime(2026, 9, 14, 16), DateTime(2026, 9, 14, 18)),
        ]),
      ],
      calendarConflictsChecked: true,
    );

    expect(result.conflictCount, 1);
    expect(result.issues.single.kind, ReplanningIssueKind.calendarConflict);
    expect(
      result.issues.single.suggestion?.startsAt,
      DateTime(2026, 9, 14, 16),
    );
  });

  test('block outside changed planning window is flagged without calendar', () {
    final block = _block(
      'late',
      DateTime(2026, 9, 14, 21),
      DateTime(2026, 9, 14, 22),
    );
    final result = engine.build(
      now: now,
      preferences: preferences(),
      blocks: [block],
      tasks: const [],
      projects: const [],
      calendarBusyEvents: const [],
      horizonAvailability: [
        _availability(DateTime(2026, 9, 15, 8), DateTime(2026, 9, 15, 20), [
          (DateTime(2026, 9, 15, 9), DateTime(2026, 9, 15, 11)),
        ]),
      ],
      calendarConflictsChecked: false,
    );

    expect(result.issues.single.kind, ReplanningIssueKind.outsideAvailability);
    expect(result.issues.single.suggestion?.startsAt, DateTime(2026, 9, 15, 9));
  });

  test(
    'urgent task is flagged when remaining work cannot fit before due date',
    () {
      final task = _task(
        'exam',
        estimate: 180,
        dueAt: DateTime(2026, 9, 14, 23, 59),
        priority: PriorityLevel.critical,
      );
      final result = engine.build(
        now: now,
        preferences: preferences(),
        blocks: const [],
        tasks: [task],
        projects: const [],
        calendarBusyEvents: const [],
        horizonAvailability: [
          _availability(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 20), [
            (DateTime(2026, 9, 14, 13), DateTime(2026, 9, 14, 14)),
          ]),
        ],
        calendarConflictsChecked: true,
      );

      expect(result.urgentCapacityCount, 1);
      expect(result.issues.single.remainingMinutes, 180);
      expect(result.issues.single.message, contains('2h'));
    },
  );

  test('non-flexible block is flagged but not offered a move', () {
    final block = _block(
      'fixed',
      DateTime(2026, 9, 14, 14),
      DateTime(2026, 9, 14, 15),
    );
    final fixedTask = Task(
      id: block.taskId,
      userId: 'user',
      title: 'Fixed task',
      isCompleted: false,
      sourceNoteId: 'note-fixed',
      sourceLineIndex: 0,
      isFlexible: false,
    );
    final result = engine.build(
      now: now,
      preferences: preferences(),
      blocks: [block],
      tasks: [fixedTask],
      projects: const [],
      calendarBusyEvents: [
        CalendarBusyEvent(
          id: 'meeting',
          title: 'Meeting',
          startsAt: DateTime(2026, 9, 14, 14),
          endsAt: DateTime(2026, 9, 14, 15),
        ),
      ],
      horizonAvailability: [
        _availability(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 20), [
          (DateTime(2026, 9, 14, 16), DateTime(2026, 9, 14, 18)),
        ]),
      ],
      calendarConflictsChecked: true,
    );

    expect(result.issues.single.kind, ReplanningIssueKind.calendarConflict);
    expect(result.issues.single.suggestion, isNull);
  });

  test(
    'urgent shortfall can suggest displacing lower-pressure flexible work',
    () {
      final due = DateTime(2026, 9, 14, 23, 59);
      final flexibleBlock = ScheduleBlock(
        id: 'agency-block',
        userId: 'user',
        taskId: 'agency',
        title: 'Agency planning',
        startsAt: DateTime(2026, 9, 14, 14),
        endsAt: DateTime(2026, 9, 14, 15),
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      );
      final result = engine.build(
        now: now,
        preferences: preferences(),
        blocks: [flexibleBlock],
        tasks: [
          _task(
            'exam',
            estimate: 120,
            dueAt: due,
            priority: PriorityLevel.critical,
          ),
          Task(
            id: 'agency',
            userId: 'user',
            title: 'Agency planning',
            isCompleted: false,
            sourceNoteId: 'note-agency',
            sourceLineIndex: 0,
            priority: PriorityLevel.low,
            isFlexible: true,
          ),
        ],
        projects: const [],
        calendarBusyEvents: const [],
        horizonAvailability: [
          _availability(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 20), [
            (DateTime(2026, 9, 14, 13), DateTime(2026, 9, 14, 14)),
          ]),
          _availability(DateTime(2026, 9, 15, 8), DateTime(2026, 9, 15, 20), [
            (DateTime(2026, 9, 15, 9), DateTime(2026, 9, 15, 11)),
          ]),
        ],
        calendarConflictsChecked: true,
      );

      final urgent = result.issues.singleWhere(
        (issue) => issue.kind == ReplanningIssueKind.urgentCapacity,
      );
      expect(urgent.block?.id, 'agency-block');
      expect(urgent.suggestion?.startsAt, DateTime(2026, 9, 15, 9));
    },
  );

  test('shared deadline capacity is consumed across urgent tasks', () {
    final due = DateTime(2026, 9, 14, 23, 59);
    final result = engine.build(
      now: now,
      preferences: preferences(),
      blocks: const [],
      tasks: [
        _task(
          'first',
          estimate: 60,
          dueAt: due,
          priority: PriorityLevel.critical,
        ),
        _task('second', estimate: 60, dueAt: due, priority: PriorityLevel.high),
      ],
      projects: const [],
      calendarBusyEvents: const [],
      horizonAvailability: [
        _availability(DateTime(2026, 9, 14, 12), DateTime(2026, 9, 14, 20), [
          (DateTime(2026, 9, 14, 13), DateTime(2026, 9, 14, 14, 30)),
        ]),
      ],
      calendarConflictsChecked: true,
    );

    expect(result.urgentCapacityCount, 1);
    expect(result.issues.single.taskId, 'second');
  });
}

ScheduleBlock _block(String id, DateTime start, DateTime end) {
  return ScheduleBlock(
    id: id,
    userId: 'user',
    taskId: 'task-$id',
    title: 'Block $id',
    startsAt: start,
    endsAt: end,
    createdAt: DateTime(2026, 9, 13),
    updatedAt: DateTime(2026, 9, 13),
  );
}

Task _task(
  String id, {
  required int estimate,
  required DateTime dueAt,
  PriorityLevel priority = PriorityLevel.none,
}) {
  return Task(
    id: id,
    userId: 'user',
    title: 'Task $id',
    isCompleted: false,
    sourceNoteId: 'note-$id',
    sourceLineIndex: 0,
    dueAt: dueAt,
    priority: priority,
    estimatedMinutes: estimate,
  );
}

AvailabilitySummary _availability(
  DateTime start,
  DateTime end,
  List<(DateTime, DateTime)> slots,
) {
  final free = slots.fold<int>(
    0,
    (sum, slot) => sum + slot.$2.difference(slot.$1).inMinutes,
  );
  return AvailabilitySummary(
    windowStart: start,
    windowEnd: end,
    busyMinutes: end.difference(start).inMinutes - free,
    freeMinutes: free,
    freeSlots: slots
        .map((slot) => AvailabilitySlot(startsAt: slot.$1, endsAt: slot.$2))
        .toList(),
  );
}
