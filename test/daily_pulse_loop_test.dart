import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calendar/models/availability_summary.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/scheduling_day_state.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';

void main() {
  final date = DateTime(2026, 9, 13);

  ScheduleBlock block({
    required String id,
    required int startHour,
    required int endHour,
    ScheduleBlockStatus status = ScheduleBlockStatus.scheduled,
  }) {
    return ScheduleBlock(
      id: id,
      userId: 'user',
      taskId: 'task-$id',
      title: 'Block $id',
      startsAt: DateTime(2026, 9, 13, startHour),
      endsAt: DateTime(2026, 9, 13, endHour),
      status: status,
      createdAt: DateTime(2026, 9, 12),
      updatedAt: DateTime(2026, 9, 12),
    );
  }

  PulseOverview pulse() {
    return const PulseOverview(
      focusItems: [],
      cues: [],
      upcomingProjects: [],
      openTaskCount: 0,
      overdueCount: 0,
      dueTodayCount: 0,
      focusEstimatedMinutes: 0,
    );
  }

  test('tracks up next, completed, missed, and unresolved blocks', () {
    final loop = DailyPulseLoop.build(
      now: DateTime(2026, 9, 13, 15),
      pulse: pulse(),
      blocks: [
        block(
          id: 'done',
          startHour: 9,
          endHour: 10,
          status: ScheduleBlockStatus.completed,
        ),
        block(id: 'review', startHour: 10, endHour: 11),
        block(
          id: 'missed',
          startHour: 11,
          endHour: 12,
          status: ScheduleBlockStatus.skipped,
        ),
        block(id: 'next', startHour: 16, endHour: 17),
      ],
    );

    expect(loop.completedCount, 1);
    expect(loop.missedCount, 1);
    expect(loop.unresolvedCount, 1);
    expect(loop.upcomingCount, 1);
    expect(loop.upNextBlock?.id, 'next');
    expect(loop.completedMinutes, 60);
    expect(loop.plannedMinutes, 240);
  });

  test(
    'closing starts two hours before configured planning end, not before 17:00',
    () {
      final preferences = SchedulingPreferences.defaults().copyWith(
        isConfigured: true,
        availableWeekdays: [DateTime.sunday],
        dayStartMinutes: 8 * 60,
        dayEndMinutes: 21 * 60,
      );
      final scheduling = SchedulingDayState(
        date: date,
        preferences: preferences,
        calendarSupported: false,
        calendarAccess: true,
        acceptedBlocks: const [],
        availability: AvailabilitySummary(
          windowStart: DateTime(2026, 9, 13, 8),
          windowEnd: DateTime(2026, 9, 13, 21),
          busyMinutes: 0,
          freeMinutes: 780,
          freeSlots: const [],
        ),
      );

      final before = DailyPulseLoop.build(
        now: DateTime(2026, 9, 13, 18, 59),
        pulse: pulse(),
        blocks: const [],
        scheduling: scheduling,
      );
      final after = DailyPulseLoop.build(
        now: DateTime(2026, 9, 13, 19),
        pulse: pulse(),
        blocks: const [],
        scheduling: scheduling,
      );

      expect(before.closingStartsAt, DateTime(2026, 9, 13, 19));
      expect(before.shouldShowClosing, isFalse);
      expect(after.shouldShowClosing, isTrue);
    },
  );

  test(
    'closing appears once all planned work has ended even before routine time',
    () {
      final loop = DailyPulseLoop.build(
        now: DateTime(2026, 9, 13, 14),
        pulse: pulse(),
        blocks: [
          block(
            id: 'done',
            startHour: 9,
            endHour: 10,
            status: ScheduleBlockStatus.completed,
          ),
        ],
      );

      expect(loop.closingStartsAt, DateTime(2026, 9, 13, 17));
      expect(loop.shouldShowClosing, isTrue);
    },
  );

  test(
    'carries scheduling capacity and replanning counts into the daily loop',
    () {
      final preferences = SchedulingPreferences.defaults().copyWith(
        isConfigured: true,
        availableWeekdays: [DateTime.sunday],
      );
      final scheduling = SchedulingDayState(
        date: date,
        preferences: preferences,
        calendarSupported: false,
        calendarAccess: true,
        acceptedBlocks: const [],
        availability: AvailabilitySummary(
          windowStart: DateTime(2026, 9, 13, 8),
          windowEnd: DateTime(2026, 9, 13, 20),
          busyMinutes: 120,
          freeMinutes: 600,
          freeSlots: const [],
        ),
      );
      final replanning = ReplanningOverview(
        generatedAt: DateTime(2026, 9, 13, 9),
        horizonEnd: DateTime(2026, 9, 19, 20),
        issues: const [],
        calendarConflictsChecked: true,
      );

      final loop = DailyPulseLoop.build(
        now: DateTime(2026, 9, 13, 9),
        pulse: pulse(),
        blocks: const [],
        scheduling: scheduling,
        replanning: replanning,
      );

      expect(loop.freeMinutes, 600);
      expect(loop.replanningIssueCount, 0);
    },
  );
}
