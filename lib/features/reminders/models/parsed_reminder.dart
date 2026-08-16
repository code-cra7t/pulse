import 'repeat_type.dart';

class ParsedReminder {
  const ParsedReminder({
    required this.dateTime,
    required this.matchedPhrase,
    this.repeat = RepeatType.none,
    this.repeatIntervalMinutes,
    this.needsScheduleChoice = false,
    this.requestsAlarm = false,
  });

  final DateTime dateTime;
  final String matchedPhrase;
  final RepeatType repeat;
  final int? repeatIntervalMinutes;
  final bool needsScheduleChoice;
  final bool requestsAlarm;

  ParsedReminder copyWith({
    DateTime? dateTime,
    String? matchedPhrase,
    RepeatType? repeat,
    Object? repeatIntervalMinutes = _unsetInterval,
    bool? needsScheduleChoice,
    bool? requestsAlarm,
  }) {
    return ParsedReminder(
      dateTime: dateTime ?? this.dateTime,
      matchedPhrase: matchedPhrase ?? this.matchedPhrase,
      repeat: repeat ?? this.repeat,
      repeatIntervalMinutes: identical(repeatIntervalMinutes, _unsetInterval)
          ? this.repeatIntervalMinutes
          : repeatIntervalMinutes as int?,
      needsScheduleChoice: needsScheduleChoice ?? this.needsScheduleChoice,
      requestsAlarm: requestsAlarm ?? this.requestsAlarm,
    );
  }
}

const _unsetInterval = Object();
