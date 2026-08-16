import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/reminders/data/smart_reminder_parser.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';

void main() {
  final parser = SmartReminderParser();
  final reference = DateTime(2026, 6, 21, 8, 0);

  test('parses tomorrow with a contextual bare hour', () {
    final result = parser.parse(
      'send the report tomorrow at 5',
      now: reference,
    );

    expect(result, isNotNull);
    expect(result!.dateTime, DateTime(2026, 6, 22, 5));
    expect(result.matchedPhrase, 'tomorrow at 5');
  });

  test('parses today with a contextual bare hour', () {
    final result = parser.parse('call Alex today at 9', now: reference);

    expect(result, isNotNull);
    expect(result!.dateTime, DateTime(2026, 6, 21, 9));
    expect(result.matchedPhrase, 'today at 9');
  });

  test('parses relative hours and next weekday', () {
    final relative = parser.parse('follow up in 2 hours', now: reference);
    final weekday = parser.parse('prepare next Monday', now: reference);

    expect(relative!.dateTime, DateTime(2026, 6, 21, 10));
    expect(weekday!.dateTime, DateTime(2026, 6, 22, 9));
  });

  test('parses relative minutes, days, and natural time phrases', () {
    final minutes = parser.parse('stretch in 30 minutes', now: reference);
    final days = parser.parse('submit it in 2 days', now: reference);
    final tomorrowMorning = parser.parse(
      'call Nina tomorrow morning',
      now: reference,
    );
    final deadline = parser.parse('finish proposal by Friday', now: reference);

    expect(minutes!.dateTime, DateTime(2026, 6, 21, 8, 30));
    expect(days!.dateTime, DateTime(2026, 6, 23, 8));
    expect(tomorrowMorning!.dateTime, DateTime(2026, 6, 22, 9));
    expect(deadline!.dateTime, DateTime(2026, 6, 26, 17));
  });

  test('parses interval and recurring schedules', () {
    final interval = parser.parse(
      'drink water every 30 minutes',
      now: reference,
    );
    final hourly = parser.parse('hourly check-in', now: reference);
    final daily = parser.parse('review notes daily at 6pm', now: reference);
    final weekly = parser.parse(
      'every Monday at 9am team sync',
      now: reference,
    );

    expect(interval!.repeat, RepeatType.interval);
    expect(interval.repeatIntervalMinutes, 30);
    expect(interval.dateTime, DateTime(2026, 6, 21, 8, 30));
    expect(hourly!.repeatIntervalMinutes, 60);
    expect(daily!.repeat, RepeatType.daily);
    expect(daily.dateTime, DateTime(2026, 6, 21, 18));
    expect(weekly!.repeat, RepeatType.weekly);
    expect(weekly.dateTime, DateTime(2026, 6, 22, 9));
  });

  test('asks the user to choose a schedule for vague recurrence', () {
    final suggestion = parser.parse(
      'I need to drink water regulary',
      now: reference,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.repeat, RepeatType.interval);
    expect(suggestion.repeatIntervalMinutes, isNull);
    expect(suggestion.needsScheduleChoice, isTrue);
  });

  test('uses next calendar week when next week is explicit', () {
    final mondayReference = DateTime(2026, 6, 22, 8);
    final general = parser.parse(
      'Next week, I need to rearrange my calendar',
      now: mondayReference,
    );
    final specific = parser.parse(
      'Next week, rearrange my calendar Monday at 6pm',
      now: mondayReference,
    );

    expect(general!.dateTime, DateTime(2026, 6, 29, 9));
    expect(specific!.dateTime, DateTime(2026, 6, 29, 18));
  });

  test('recognizes natural from-now alarm requests', () {
    final alarm = parser.parse(
      'I need an alarm for an hour from now',
      now: reference,
    );
    final halfHour = parser.parse(
      'wake me half an hour from now',
      now: reference,
    );

    expect(alarm!.dateTime, DateTime(2026, 6, 21, 9));
    expect(alarm.requestsAlarm, isTrue);
    expect(halfHour!.dateTime, DateTime(2026, 6, 21, 8, 30));
    expect(halfHour.requestsAlarm, isTrue);
  });
}
