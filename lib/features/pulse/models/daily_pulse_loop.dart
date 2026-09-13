import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/scheduling_day_state.dart';
import 'pulse_overview.dart';

class DailyPulseLoop {
  const DailyPulseLoop({
    required this.date,
    required this.focusCount,
    required this.focusEstimatedMinutes,
    required this.freeMinutes,
    required this.acceptedMinutes,
    required this.proposedMinutes,
    required this.unscheduledTaskCount,
    required this.replanningIssueCount,
    required this.todayBlocks,
    required this.completedBlocks,
    required this.missedBlocks,
    required this.unresolvedPastBlocks,
    required this.upcomingBlocks,
    required this.completedMinutes,
    required this.plannedMinutes,
    required this.closingStartsAt,
    required this.shouldShowClosing,
    this.upNextBlock,
  });

  final DateTime date;
  final int focusCount;
  final int focusEstimatedMinutes;
  final int freeMinutes;
  final int acceptedMinutes;
  final int proposedMinutes;
  final int unscheduledTaskCount;
  final int replanningIssueCount;
  final List<ScheduleBlock> todayBlocks;
  final List<ScheduleBlock> completedBlocks;
  final List<ScheduleBlock> missedBlocks;
  final List<ScheduleBlock> unresolvedPastBlocks;
  final List<ScheduleBlock> upcomingBlocks;
  final int completedMinutes;
  final int plannedMinutes;
  final DateTime closingStartsAt;
  final bool shouldShowClosing;
  final ScheduleBlock? upNextBlock;

  int get completedCount => completedBlocks.length;
  int get missedCount => missedBlocks.length;
  int get unresolvedCount => unresolvedPastBlocks.length;
  int get upcomingCount => upcomingBlocks.length;

  factory DailyPulseLoop.build({
    required DateTime now,
    required PulseOverview pulse,
    required List<ScheduleBlock> blocks,
    SchedulingDayState? scheduling,
    ReplanningOverview? replanning,
  }) {
    final date = DateTime(now.year, now.month, now.day);
    final todayBlocks =
        blocks
            .where((block) => _sameDay(block.startsAt, date))
            .toList(growable: false)
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final completed = todayBlocks
        .where((block) => block.status == ScheduleBlockStatus.completed)
        .toList(growable: false);
    final missed = todayBlocks
        .where((block) => block.status == ScheduleBlockStatus.skipped)
        .toList(growable: false);
    final unresolvedPast = todayBlocks
        .where(
          (block) =>
              block.status == ScheduleBlockStatus.scheduled &&
              !block.endsAt.isAfter(now),
        )
        .toList(growable: false);
    final upcoming = todayBlocks
        .where(
          (block) =>
              block.status == ScheduleBlockStatus.scheduled &&
              block.endsAt.isAfter(now),
        )
        .toList(growable: false);

    final upNext = upcoming.isEmpty ? null : upcoming.first;
    final proposal = scheduling?.proposal;
    final acceptedMinutes =
        proposal?.acceptedMinutes ??
        todayBlocks
            .where((block) => block.countsTowardFocusBudget)
            .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
    final closingStartsAt = _closingStart(date, scheduling);
    final allPlannedWorkHasEnded =
        todayBlocks.isNotEmpty &&
        todayBlocks.every(
          (block) =>
              block.status != ScheduleBlockStatus.scheduled ||
              !block.endsAt.isAfter(now),
        );

    return DailyPulseLoop(
      date: date,
      focusCount: pulse.focusItems.length,
      focusEstimatedMinutes: pulse.focusEstimatedMinutes,
      freeMinutes: scheduling?.availability?.freeMinutes ?? 0,
      acceptedMinutes: acceptedMinutes,
      proposedMinutes: proposal?.proposedMinutes ?? 0,
      unscheduledTaskCount: proposal?.unscheduledTaskCount ?? 0,
      replanningIssueCount: replanning?.issues.length ?? 0,
      todayBlocks: List.unmodifiable(todayBlocks),
      completedBlocks: List.unmodifiable(completed),
      missedBlocks: List.unmodifiable(missed),
      unresolvedPastBlocks: List.unmodifiable(unresolvedPast),
      upcomingBlocks: List.unmodifiable(upcoming),
      completedMinutes: completed.fold<int>(
        0,
        (sum, block) => sum + block.duration.inMinutes,
      ),
      plannedMinutes: todayBlocks.fold<int>(
        0,
        (sum, block) => sum + block.duration.inMinutes,
      ),
      closingStartsAt: closingStartsAt,
      shouldShowClosing:
          !now.isBefore(closingStartsAt) || allPlannedWorkHasEnded,
      upNextBlock: upNext,
    );
  }
}

DateTime _closingStart(DateTime date, SchedulingDayState? scheduling) {
  final defaultStart = DateTime(date.year, date.month, date.day, 17);
  if (scheduling == null ||
      !scheduling.preferences.isConfigured ||
      !scheduling.preferences.isEnabledOn(date)) {
    return defaultStart;
  }

  final preferred = scheduling.preferences
      .endFor(date)
      .subtract(const Duration(hours: 2));
  return preferred.isAfter(defaultStart) ? preferred : defaultStart;
}

bool _sameDay(DateTime value, DateTime day) {
  return value.year == day.year &&
      value.month == day.month &&
      value.day == day.day;
}
