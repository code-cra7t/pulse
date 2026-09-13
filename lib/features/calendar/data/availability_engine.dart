import '../models/availability_summary.dart';
import '../models/calendar_busy_event.dart';

class AvailabilityEngine {
  const AvailabilityEngine();

  AvailabilitySummary calculate({
    required DateTime windowStart,
    required DateTime windowEnd,
    required Iterable<CalendarBusyEvent> busyEvents,
    Duration minimumSlot = const Duration(minutes: 15),
  }) {
    if (!windowEnd.isAfter(windowStart)) {
      throw ArgumentError('windowEnd must be after windowStart.');
    }
    if (minimumSlot.isNegative) {
      throw ArgumentError.value(
        minimumSlot,
        'minimumSlot',
        'must not be negative',
      );
    }

    final clipped = <_BusyInterval>[];
    for (final event in busyEvents) {
      if (!event.isValid ||
          !event.endsAt.isAfter(windowStart) ||
          !event.startsAt.isBefore(windowEnd)) {
        continue;
      }
      final start = event.startsAt.isBefore(windowStart)
          ? windowStart
          : event.startsAt;
      final end = event.endsAt.isAfter(windowEnd) ? windowEnd : event.endsAt;
      if (end.isAfter(start)) {
        clipped.add(_BusyInterval(start, end));
      }
    }

    clipped.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_BusyInterval>[];
    for (final interval in clipped) {
      if (merged.isEmpty || interval.start.isAfter(merged.last.end)) {
        merged.add(interval);
        continue;
      }
      if (interval.end.isAfter(merged.last.end)) {
        merged[merged.length - 1] = _BusyInterval(
          merged.last.start,
          interval.end,
        );
      }
    }

    var cursor = windowStart;
    final freeSlots = <AvailabilitySlot>[];
    var busyMinutes = 0;
    for (final interval in merged) {
      final gap = interval.start.difference(cursor);
      if (!gap.isNegative && gap >= minimumSlot) {
        freeSlots.add(
          AvailabilitySlot(startsAt: cursor, endsAt: interval.start),
        );
      }
      busyMinutes += interval.end.difference(interval.start).inMinutes;
      if (interval.end.isAfter(cursor)) {
        cursor = interval.end;
      }
    }

    final tail = windowEnd.difference(cursor);
    if (!tail.isNegative && tail >= minimumSlot) {
      freeSlots.add(AvailabilitySlot(startsAt: cursor, endsAt: windowEnd));
    }

    final totalMinutes = windowEnd.difference(windowStart).inMinutes;
    final freeMinutes = totalMinutes - busyMinutes;

    return AvailabilitySummary(
      windowStart: windowStart,
      windowEnd: windowEnd,
      busyMinutes: busyMinutes,
      freeMinutes: freeMinutes < 0 ? 0 : freeMinutes,
      freeSlots: List.unmodifiable(freeSlots),
    );
  }
}

class _BusyInterval {
  const _BusyInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;
}
