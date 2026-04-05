import '../models/parsed_reminder.dart';

class SmartReminderParser {
  static final RegExp _inHoursPattern = RegExp(
    r'\bin\s+(\d+)\s+hours?\b',
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

  static const Map<String, int> _weekdayMap = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  ParsedReminder? parse(
    String input, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final normalized = input.trim().toLowerCase();

    final inHours = _parseInHours(normalized, reference);
    if (inHours != null) {
      return inHours;
    }

    final nextWeekday = _parseNextWeekday(normalized, reference);
    if (nextWeekday != null) {
      return nextWeekday;
    }

    final todayWithTime = _parseTodayOrTomorrow(normalized, reference);
    if (todayWithTime != null) {
      return todayWithTime;
    }

    final standaloneTime = _parseStandaloneTime(normalized, reference);
    if (standaloneTime != null) {
      return standaloneTime;
    }

    return null;
  }

  ParsedReminder? _parseInHours(String input, DateTime now) {
    final match = _inHoursPattern.firstMatch(input);
    if (match == null) {
      return null;
    }

    final hours = int.tryParse(match.group(1) ?? '');
    if (hours == null) {
      return null;
    }

    return ParsedReminder(
      dateTime: now.add(Duration(hours: hours)),
      matchedPhrase: match.group(0) ?? '',
    );
  }

  ParsedReminder? _parseNextWeekday(String input, DateTime now) {
    for (final entry in _weekdayMap.entries) {
      final phrase = 'next ${entry.key}';
      if (!input.contains(phrase)) {
        continue;
      }

      final time = _extractTime(input);
      final date = _nextWeekday(now, entry.value);
      final scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );

      return ParsedReminder(
        dateTime: scheduled,
        matchedPhrase: phrase,
      );
    }

    return null;
  }

  ParsedReminder? _parseTodayOrTomorrow(String input, DateTime now) {
    final hasToday = input.contains('today');
    final hasTomorrow = input.contains('tomorrow');
    if (!hasToday && !hasTomorrow) {
      return null;
    }

    final time = _extractTime(input);
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
        : scheduled.add(const Duration(hours: 1));

    return ParsedReminder(
      dateTime: adjusted,
      matchedPhrase: hasTomorrow ? 'tomorrow' : 'today',
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

  _ParsedTime? _extractTime(String input) {
    final twelveHourMatch = _twelveHourTimePattern.firstMatch(input);
    if (twelveHourMatch != null) {
      final rawHour = int.parse(twelveHourMatch.group(1)!);
      final minute = int.tryParse(twelveHourMatch.group(2) ?? '0') ?? 0;
      final meridiem = (twelveHourMatch.group(3) ?? '').toLowerCase();
      final hour = _to24Hour(rawHour, meridiem);

      return _ParsedTime(
        hour: hour,
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

    return null;
  }

  int _to24Hour(int hour, String meridiem) {
    if (meridiem == 'am') {
      return hour == 12 ? 0 : hour;
    }

    return hour == 12 ? 12 : hour + 12;
  }

  DateTime _nextWeekday(DateTime now, int weekday) {
    var date = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );

    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }

    return date;
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
