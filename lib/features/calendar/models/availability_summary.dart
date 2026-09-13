class AvailabilitySlot {
  const AvailabilitySlot({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;

  Duration get duration => endsAt.difference(startsAt);
}

class AvailabilitySummary {
  const AvailabilitySummary({
    required this.windowStart,
    required this.windowEnd,
    required this.busyMinutes,
    required this.freeMinutes,
    required this.freeSlots,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final int busyMinutes;
  final int freeMinutes;
  final List<AvailabilitySlot> freeSlots;

  Duration get windowDuration => windowEnd.difference(windowStart);
}
