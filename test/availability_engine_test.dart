import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calendar/data/availability_engine.dart';
import 'package:pulse/features/calendar/models/calendar_busy_event.dart';

void main() {
  const engine = AvailabilityEngine();
  final day = DateTime(2026, 9, 14);
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  CalendarBusyEvent event(
    String id,
    DateTime start,
    DateTime end, {
    bool allDay = false,
  }) {
    return CalendarBusyEvent(
      id: id,
      title: id,
      startsAt: start,
      endsAt: end,
      isAllDay: allDay,
    );
  }

  test('merges overlapping busy events before calculating free time', () {
    final summary = engine.calculate(
      windowStart: at(8),
      windowEnd: at(18),
      busyEvents: [
        event('a', at(9), at(11)),
        event('b', at(10, 30), at(12)),
        event('c', at(14), at(15)),
      ],
    );

    expect(summary.busyMinutes, 240);
    expect(summary.freeMinutes, 360);
    expect(summary.freeSlots, hasLength(3));
    expect(summary.freeSlots[0].startsAt, at(8));
    expect(summary.freeSlots[0].endsAt, at(9));
    expect(summary.freeSlots[1].startsAt, at(12));
    expect(summary.freeSlots[1].endsAt, at(14));
    expect(summary.freeSlots[2].startsAt, at(15));
    expect(summary.freeSlots[2].endsAt, at(18));
  });

  test('clips busy events to the requested availability window', () {
    final summary = engine.calculate(
      windowStart: at(8),
      windowEnd: at(18),
      busyEvents: [
        event('early', at(6), at(9)),
        event('late', at(17), at(20)),
        event('outside', at(20), at(21)),
      ],
    );

    expect(summary.busyMinutes, 120);
    expect(summary.freeMinutes, 480);
    expect(summary.freeSlots.single.startsAt, at(9));
    expect(summary.freeSlots.single.endsAt, at(17));
  });

  test('filters free gaps shorter than the requested minimum slot', () {
    final summary = engine.calculate(
      windowStart: at(8),
      windowEnd: at(12),
      busyEvents: [event('a', at(8, 30), at(9)), event('b', at(9, 10), at(10))],
      minimumSlot: const Duration(minutes: 30),
    );

    expect(summary.freeMinutes, 160);
    expect(summary.freeSlots, hasLength(2));
    expect(summary.freeSlots[0].startsAt, at(8));
    expect(summary.freeSlots[0].endsAt, at(8, 30));
    expect(summary.freeSlots[1].startsAt, at(10));
    expect(summary.freeSlots[1].endsAt, at(12));
  });

  test('an all-day event can block the full requested window', () {
    final summary = engine.calculate(
      windowStart: at(8),
      windowEnd: at(18),
      busyEvents: [
        event('all-day', day, day.add(const Duration(days: 1)), allDay: true),
      ],
    );

    expect(summary.busyMinutes, 600);
    expect(summary.freeMinutes, 0);
    expect(summary.freeSlots, isEmpty);
  });

  test('invalid or outside busy events do not reduce availability', () {
    final summary = engine.calculate(
      windowStart: at(8),
      windowEnd: at(18),
      busyEvents: [
        event('invalid', at(10), at(10)),
        event('before', at(6), at(7)),
      ],
    );

    expect(summary.busyMinutes, 0);
    expect(summary.freeMinutes, 600);
    expect(summary.freeSlots.single.duration, const Duration(hours: 10));
  });
}
