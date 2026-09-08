import '../../features/reminders/models/repeat_type.dart';

/// Returns the first occurrence strictly after [now].
///
/// Calendar repeats keep their local wall-clock time across daylight-saving
/// changes. Interval repeats stay anchored to the original scheduled instant.
DateTime nextReminderOccurrence({
  required DateTime scheduledAt,
  required RepeatType repeat,
  required DateTime now,
  int? repeatIntervalMinutes,
}) {
  if (repeat == RepeatType.none) {
    return scheduledAt.isAfter(now)
        ? scheduledAt
        : now.add(const Duration(minutes: 1));
  }

  if (repeat == RepeatType.interval) {
    final intervalMinutes = repeatIntervalMinutes ?? 30;
    if (scheduledAt.isAfter(now)) {
      return scheduledAt;
    }
    final interval = Duration(minutes: intervalMinutes);
    final elapsed = now.difference(scheduledAt).inMicroseconds;
    final skipped = elapsed ~/ interval.inMicroseconds + 1;
    return scheduledAt.add(
      Duration(microseconds: skipped * interval.inMicroseconds),
    );
  }

  final stepDays = repeat == RepeatType.daily ? 1 : 7;
  var next = scheduledAt;
  while (!next.isAfter(now)) {
    next = DateTime(
      next.year,
      next.month,
      next.day + stepDays,
      scheduledAt.hour,
      scheduledAt.minute,
      scheduledAt.second,
      scheduledAt.millisecond,
      scheduledAt.microsecond,
    );
  }
  return next;
}
