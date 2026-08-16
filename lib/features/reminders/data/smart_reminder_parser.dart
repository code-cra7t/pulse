import '../models/parsed_reminder.dart';
import '../models/repeat_type.dart';

/// A small, on-device language helper for common reminder phrasing.
///
/// It intentionally produces suggestions only. The UI always asks the user to
/// confirm before anything is scheduled.
class SmartReminderParser {
  static final RegExp _relativePattern = RegExp(
    r'\bin\s+(\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)\b',
    caseSensitive: false,
  );
  static final RegExp _fromNowPattern = RegExp(
    r'\b(a|an|one|\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)\s+from\s+now\b',
    caseSensitive: false,
  );
  static final RegExp _vagueRecurrencePattern = RegExp(
    r'\b(regularly|regulary|frequently|often|throughout the day)\b',
    caseSensitive: false,
  );
  static final RegExp _alarmIntentPattern = RegExp(
    r'\b(alarm|wake me)\b',
    caseSensitive: false,
  );
  static final RegExp _intervalPattern = RegExp(
    r'\bevery\s+(\d+)\s+(minutes?|mins?|hours?|hrs?)\b',
    caseSensitive: false,
  );
  static final RegExp _twelveHourTimePattern = RegExp(
    r'\b(1[0-2]|0?[1-9])(?::([0-5][0-9]))?\s?(am|pm)\b',
    caseSensitive: false,
  );
  static final RegExp _twentyFourHourTimePattern = RegExp(
    r'\b([01]?\d|2[0-3]):([0-5][0-9])\b',
    caseSensitive: false,
  );
  static final RegExp _contextHourPattern = RegExp(
    r'\bat\s+([01]?\d|2[0-3])(?:[:.]([0-5][0-9]))?\b',
    caseSensitive: false,
  );
  static final RegExp _weekdayPattern = RegExp(
    r'\b(next|this|on|by)?\s*'
    r'(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );

  static const Map<String, int> _weekdayMap = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  ParsedReminder? parse(String input, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final parsed =
        _parseInterval(normalized, reference) ??
        _parseRecurringSchedule(normalized, reference) ??
        _parseRelativeTime(normalized, reference) ??
        _parseNextWeek(normalized, reference) ??
        _parseWeekend(normalized, reference) ??
        _parseWeekday(normalized, reference) ??
        _parseTodayTomorrowOrNaturalTime(normalized, reference) ??
        _parseStandaloneTime(normalized, reference) ??
        _parseVagueRecurrence(normalized, reference);

    if (parsed == null) {
      return null;
    }
    return _alarmIntentPattern.hasMatch(normalized)
        ? parsed.copyWith(requestsAlarm: true)
        : parsed;
  }

  ParsedReminder? _parseInterval(String input, DateTime now) {
    final intervalMatch = _intervalPattern.firstMatch(input);
    var minutes = 0;
    var phrase = '';
    if (intervalMatch != null) {
      final amount = int.tryParse(intervalMatch.group(1) ?? '');
      if (amount == null || amount <= 0) {
        return null;
      }
      final unit = (intervalMatch.group(2) ?? '').toLowerCase();
      minutes = unit.startsWith('hour') || unit.startsWith('hr')
          ? amount * 60
          : amount;
      phrase = intervalMatch.group(0) ?? '';
    } else if (input.contains('hourly') || input.contains('every hour')) {
      minutes = 60;
      phrase = input.contains('hourly') ? 'hourly' : 'every hour';
    }

    if (minutes < 15) {
      return null;
    }

    return ParsedReminder(
      dateTime: now.add(Duration(minutes: minutes)),
      matchedPhrase: phrase,
      repeat: RepeatType.interval,
      repeatIntervalMinutes: minutes,
    );
  }

  ParsedReminder? _parseRecurringSchedule(String input, DateTime now) {
    final everyWeekday = RegExp(
      r'\bevery\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
      caseSensitive: false,
    ).firstMatch(input);
    if (everyWeekday != null) {
      final weekdayName = (everyWeekday.group(1) ?? '').toLowerCase();
      final time = _extractTime(input) ?? _naturalTime(input);
      final date = _upcomingWeekday(
        now,
        _weekdayMap[weekdayName]!,
        time ?? const _ParsedTime(hour: 9, minute: 0, matchedPhrase: ''),
      );
      return ParsedReminder(
        dateTime: date,
        matchedPhrase: time == null
            ? everyWeekday.group(0)!
            : '${everyWeekday.group(0)} ${time.matchedPhrase}',
        repeat: RepeatType.weekly,
      );
    }

    final daily =
        input.contains('every day') ||
        input.contains('daily') ||
        input.contains('every morning') ||
        input.contains('every evening');
    final weekly = input.contains('every week') || input.contains('weekly');
    if (!daily && !weekly) {
      return null;
    }

    final time = _extractTime(input) ?? _naturalTime(input);
    final defaultTime =
        time ?? const _ParsedTime(hour: 9, minute: 0, matchedPhrase: '');
    final todayAtTime = DateTime(
      now.year,
      now.month,
      now.day,
      defaultTime.hour,
      defaultTime.minute,
    );
    final scheduled = todayAtTime.isAfter(now)
        ? todayAtTime
        : todayAtTime.add(Duration(days: weekly ? 7 : 1));
    final phrase = daily
        ? (time == null ? 'daily' : 'daily ${time.matchedPhrase}')
        : (time == null ? 'weekly' : 'weekly ${time.matchedPhrase}');

    return ParsedReminder(
      dateTime: scheduled,
      matchedPhrase: phrase,
      repeat: daily ? RepeatType.daily : RepeatType.weekly,
    );
  }

  ParsedReminder? _parseRelativeTime(String input, DateTime now) {
    if (RegExp(
      r'\bhalf\s+an?\s+hour\s+from\s+now\b',
      caseSensitive: false,
    ).hasMatch(input)) {
      return ParsedReminder(
        dateTime: now.add(const Duration(minutes: 30)),
        matchedPhrase: 'half an hour from now',
      );
    }

    final match =
        _relativePattern.firstMatch(input) ?? _fromNowPattern.firstMatch(input);
    if (match == null) {
      return null;
    }

    final amountText = (match.group(1) ?? '').toLowerCase();
    final amount = switch (amountText) {
      'a' || 'an' || 'one' => 1,
      _ => int.tryParse(amountText),
    };
    if (amount == null || amount <= 0) {
      return null;
    }
    final unit = (match.group(2) ?? '').toLowerCase();
    final duration = unit.startsWith('min')
        ? Duration(minutes: amount)
        : unit.startsWith('hour') || unit.startsWith('hr')
        ? Duration(hours: amount)
        : unit.startsWith('day')
        ? Duration(days: amount)
        : Duration(days: amount * 7);

    return ParsedReminder(
      dateTime: now.add(duration),
      matchedPhrase: match.group(0) ?? '',
    );
  }

  ParsedReminder? _parseNextWeek(String input, DateTime now) {
    if (!input.contains('next week')) {
      return null;
    }

    final weekdayMatch = _weekdayPattern.firstMatch(input);
    final weekdayName = weekdayMatch?.group(2)?.toLowerCase();
    final targetWeekday = weekdayName == null
        ? DateTime.monday
        : _weekdayMap[weekdayName]!;
    final time = _extractTime(input) ?? _naturalTime(input);
    final selectedTime =
        time ?? const _ParsedTime(hour: 9, minute: 0, matchedPhrase: '');
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final startOfNextWeek = startOfThisWeek.add(const Duration(days: 7));
    final targetDate = startOfNextWeek.add(Duration(days: targetWeekday - 1));
    final scheduled = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final weekdayPhrase = weekdayName == null ? '' : ' $weekdayName';
    final timePhrase = time == null ? '' : ' ${time.matchedPhrase}';
    return ParsedReminder(
      dateTime: scheduled,
      matchedPhrase: 'next week$weekdayPhrase$timePhrase',
    );
  }

  ParsedReminder? _parseVagueRecurrence(String input, DateTime now) {
    final match = _vagueRecurrencePattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    return ParsedReminder(
      dateTime: now.add(const Duration(hours: 1)),
      matchedPhrase: match.group(0) ?? 'regularly',
      repeat: RepeatType.interval,
      needsScheduleChoice: true,
    );
  }

  ParsedReminder? _parseWeekend(String input, DateTime now) {
    if (!input.contains('weekend')) {
      return null;
    }
    final time = _extractTime(input) ?? _naturalTime(input);
    final selectedTime =
        time ?? const _ParsedTime(hour: 10, minute: 0, matchedPhrase: '');
    var date = DateTime(now.year, now.month, now.day);
    while (date.weekday != DateTime.saturday) {
      date = date.add(const Duration(days: 1));
    }
    var scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return ParsedReminder(
      dateTime: scheduled,
      matchedPhrase: time == null
          ? 'this weekend'
          : 'this weekend ${time.matchedPhrase}',
    );
  }

  ParsedReminder? _parseWeekday(String input, DateTime now) {
    final match = _weekdayPattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    final qualifier = (match.group(1) ?? '').toLowerCase();
    final weekdayName = (match.group(2) ?? '').toLowerCase();
    final time = _extractTime(input) ?? _naturalTime(input);
    final isDeadline = qualifier == 'by';
    final defaultTime = _ParsedTime(
      hour: isDeadline ? 17 : 9,
      minute: 0,
      matchedPhrase: '',
    );
    final selectedTime = time ?? defaultTime;
    final scheduled = qualifier == 'next'
        ? _nextWeekday(now, _weekdayMap[weekdayName]!, selectedTime)
        : _upcomingWeekday(now, _weekdayMap[weekdayName]!, selectedTime);
    final phrase = match.group(0)!.trim();
    return ParsedReminder(
      dateTime: scheduled,
      matchedPhrase: time == null ? phrase : '$phrase ${time.matchedPhrase}',
    );
  }

  ParsedReminder? _parseTodayTomorrowOrNaturalTime(String input, DateTime now) {
    final hasToday = input.contains('today');
    final hasTomorrow = input.contains('tomorrow');
    final naturalTime = _naturalTime(input);
    if (!hasToday && !hasTomorrow && naturalTime == null) {
      return null;
    }

    final time = _extractTime(input) ?? naturalTime;
    final baseDate = hasTomorrow ? now.add(const Duration(days: 1)) : now;
    final scheduled = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      time?.hour ?? now.hour,
      time?.minute ?? now.minute,
    );
    final adjusted = scheduled.isAfter(now)
        ? scheduled
        : hasToday
        ? now.add(const Duration(hours: 1))
        : naturalTime != null
        ? scheduled.add(const Duration(days: 1))
        : scheduled;
    final dayPhrase = hasTomorrow
        ? 'tomorrow'
        : hasToday
        ? 'today'
        : naturalTime!.matchedPhrase;

    return ParsedReminder(
      dateTime: adjusted,
      matchedPhrase: hasToday || hasTomorrow
          ? (time == null ? dayPhrase : '$dayPhrase ${time.matchedPhrase}')
          : dayPhrase,
    );
  }

  ParsedReminder? _parseStandaloneTime(String input, DateTime now) {
    final time = _extractTime(input);
    if (time == null) {
      return null;
    }
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return ParsedReminder(
      dateTime: scheduled.isAfter(now)
          ? scheduled
          : scheduled.add(const Duration(days: 1)),
      matchedPhrase: time.matchedPhrase,
    );
  }

  _ParsedTime? _naturalTime(String input) {
    if (input.contains('end of day') || input.contains('eod')) {
      return const _ParsedTime(
        hour: 17,
        minute: 0,
        matchedPhrase: 'end of day',
      );
    }
    if (input.contains('tonight')) {
      return const _ParsedTime(hour: 19, minute: 0, matchedPhrase: 'tonight');
    }
    if (input.contains('afternoon') || input.contains('after lunch')) {
      return const _ParsedTime(
        hour: 15,
        minute: 0,
        matchedPhrase: 'this afternoon',
      );
    }
    if (input.contains('evening')) {
      return const _ParsedTime(
        hour: 18,
        minute: 0,
        matchedPhrase: 'this evening',
      );
    }
    if (input.contains('morning')) {
      return const _ParsedTime(hour: 9, minute: 0, matchedPhrase: 'morning');
    }
    if (input.contains('noon')) {
      return const _ParsedTime(hour: 12, minute: 0, matchedPhrase: 'noon');
    }
    return null;
  }

  _ParsedTime? _extractTime(String input) {
    final twelveHourMatch = _twelveHourTimePattern.firstMatch(input);
    if (twelveHourMatch != null) {
      final rawHour = int.parse(twelveHourMatch.group(1)!);
      final minute = int.tryParse(twelveHourMatch.group(2) ?? '0') ?? 0;
      return _ParsedTime(
        hour: _to24Hour(
          rawHour,
          (twelveHourMatch.group(3) ?? '').toLowerCase(),
        ),
        minute: minute,
        matchedPhrase: twelveHourMatch.group(0) ?? '',
      );
    }
    final twentyFourHourMatch = _twentyFourHourTimePattern.firstMatch(input);
    if (twentyFourHourMatch != null) {
      return _ParsedTime(
        hour: int.parse(twentyFourHourMatch.group(1)!),
        minute: int.parse(twentyFourHourMatch.group(2)!),
        matchedPhrase: twentyFourHourMatch.group(0) ?? '',
      );
    }
    final contextHourMatch = _contextHourPattern.firstMatch(input);
    if (contextHourMatch != null) {
      return _ParsedTime(
        hour: int.parse(contextHourMatch.group(1)!),
        minute: int.tryParse(contextHourMatch.group(2) ?? '0') ?? 0,
        matchedPhrase: contextHourMatch.group(0) ?? '',
      );
    }
    return null;
  }

  int _to24Hour(int hour, String meridiem) {
    if (meridiem == 'am') {
      return hour == 12 ? 0 : hour;
    }
    return hour == 12 ? 12 : hour + 12;
  }

  DateTime _upcomingWeekday(DateTime now, int weekday, _ParsedTime time) {
    var date = DateTime(now.year, now.month, now.day);
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return scheduled.isAfter(now)
        ? scheduled
        : scheduled.add(const Duration(days: 7));
  }

  DateTime _nextWeekday(DateTime now, int weekday, _ParsedTime time) {
    var date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _ParsedTime {
  const _ParsedTime({
    required this.hour,
    required this.minute,
    required this.matchedPhrase,
  });

  final int hour;
  final int minute;
  final String matchedPhrase;
}
