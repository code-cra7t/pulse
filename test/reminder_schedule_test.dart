import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/reminder_schedule.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';

void main() {
  group('nextReminderOccurrence', () {
    test('keeps a future interval start instead of starting immediately', () {
      final start = DateTime(2026, 9, 8, 14, 30);

      expect(
        nextReminderOccurrence(
          scheduledAt: start,
          repeat: RepeatType.interval,
          repeatIntervalMinutes: 45,
          now: DateTime(2026, 9, 8, 12),
        ),
        start,
      );
    });

    test('advances an interval from its original anchor', () {
      expect(
        nextReminderOccurrence(
          scheduledAt: DateTime(2026, 9, 8, 10),
          repeat: RepeatType.interval,
          repeatIntervalMinutes: 45,
          now: DateTime(2026, 9, 8, 12, 1),
        ),
        DateTime(2026, 9, 8, 12, 15),
      );
    });

    test('keeps the selected wall-clock time for calendar repeats', () {
      expect(
        nextReminderOccurrence(
          scheduledAt: DateTime(2026, 3, 28, 9, 15),
          repeat: RepeatType.daily,
          now: DateTime(2026, 3, 30, 10),
        ),
        DateTime(2026, 3, 31, 9, 15),
      );
      expect(
        nextReminderOccurrence(
          scheduledAt: DateTime(2026, 9, 1, 18, 20),
          repeat: RepeatType.weekly,
          now: DateTime(2026, 9, 15, 18, 20),
        ),
        DateTime(2026, 9, 22, 18, 20),
      );
    });
  });
}
