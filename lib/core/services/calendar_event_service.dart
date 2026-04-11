import 'package:add_2_calendar/add_2_calendar.dart';

import '../../features/reminders/models/repeat_type.dart';

class CalendarEventService {
  Future<void> addReminderToCalendar({
    required String title,
    required String body,
    required DateTime scheduledAt,
    required RepeatType repeat,
  }) {
    final event = Event(
      title: title,
      description: body,
      startDate: scheduledAt,
      endDate: scheduledAt.add(const Duration(minutes: 30)),
      recurrence: _recurrenceFor(repeat),
    );

    return Add2Calendar.addEvent2Cal(event);
  }

  Recurrence? _recurrenceFor(RepeatType repeat) {
    return switch (repeat) {
      RepeatType.none => null,
      RepeatType.daily => Recurrence(frequency: Frequency.daily),
      RepeatType.weekly => Recurrence(frequency: Frequency.weekly),
    };
  }
}
