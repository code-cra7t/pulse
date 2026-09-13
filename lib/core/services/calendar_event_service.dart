import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/reminders/models/repeat_type.dart';

class CalendarEventService {
  static const _channel = MethodChannel('com.tori.pulse/calendar');

  bool get supportsManagedEvents =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> addReminderToCalendar({
    required String reminderId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required RepeatType repeat,
    int? repeatIntervalMinutes,
  }) async {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        repeat == RepeatType.interval) {
      throw UnsupportedError(
        'Custom repeat calendar entries are not supported by iOS Calendar.',
      );
    }
    if (supportsManagedEvents) {
      await _channel.invokeMethod<void>(
        'upsert',
        _arguments(
          reminderId,
          title,
          body,
          scheduledAt,
          repeat,
          repeatIntervalMinutes,
        ),
      );
      return;
    }
    if (repeat == RepeatType.interval) {
      throw UnsupportedError(
        'Custom repeat calendar entries are unavailable on this platform.',
      );
    }
    final event = Event(
      title: title,
      description: body,
      startDate: scheduledAt,
      endDate: scheduledAt.add(const Duration(minutes: 30)),
      recurrence: _recurrenceFor(repeat),
    );

    await Add2Calendar.addEvent2Cal(event);
  }

  /// Updates only an event previously linked on this device; never exports one.
  Future<void> updateLinkedReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required RepeatType repeat,
    int? repeatIntervalMinutes,
  }) async {
    if (!supportsManagedEvents) return;
    await _channel.invokeMethod<void>(
      'updateLinked',
      _arguments(
        reminderId,
        title,
        body,
        scheduledAt,
        repeat,
        repeatIntervalMinutes,
      ),
    );
  }

  Future<void> removeReminderFromCalendar(String reminderId) async {
    if (!supportsManagedEvents) return;
    await _channel.invokeMethod<void>('remove', {'reminderId': reminderId});
  }

  /// Retry deletes queued while calendar permission was unavailable.
  Future<void> retryPendingRemovals() async {
    if (!supportsManagedEvents) return;
    await _channel.invokeMethod<void>('retryPendingRemovals');
  }

  Map<String, Object?> _arguments(
    String id,
    String title,
    String body,
    DateTime at,
    RepeatType repeat,
    int? interval,
  ) => {
    'reminderId': id,
    'title': title,
    'body': body,
    'scheduledAt': at.millisecondsSinceEpoch,
    'repeat': repeat.value,
    'repeatIntervalMinutes': interval,
  };

  Recurrence? _recurrenceFor(RepeatType repeat) {
    return switch (repeat) {
      RepeatType.none => null,
      RepeatType.daily => Recurrence(frequency: Frequency.daily),
      RepeatType.weekly => Recurrence(frequency: Frequency.weekly),
      RepeatType.interval => null,
    };
  }
}
