class ScheduleProposal {
  const ScheduleProposal({
    required this.id,
    required this.taskId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
    required this.score,
    required this.assumedEffort,
    this.projectId,
  });

  final String id;
  final String taskId;
  final String title;
  final String? projectId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
  final int score;
  final bool assumedEffort;

  int get minutes => endsAt.difference(startsAt).inMinutes;
}

class DayScheduleProposal {
  const DayScheduleProposal({
    required this.date,
    required this.freeMinutes,
    required this.acceptedMinutes,
    required this.proposedMinutes,
    required this.proposals,
    required this.unscheduledTaskCount,
    required this.assumedEffortCount,
  });

  final DateTime date;
  final int freeMinutes;
  final int acceptedMinutes;
  final int proposedMinutes;
  final List<ScheduleProposal> proposals;
  final int unscheduledTaskCount;
  final int assumedEffortCount;

  int get remainingFreeMinutes {
    final remaining = freeMinutes - proposedMinutes;
    return remaining < 0 ? 0 : remaining;
  }
}
