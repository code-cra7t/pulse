import 'repeat_type.dart';

class ParsedReminder {
  const ParsedReminder({
    required this.dateTime,
    required this.matchedPhrase,
    this.repeat = RepeatType.none,
    this.repeatIntervalMinutes,
  });

  final DateTime dateTime;
  final String matchedPhrase;
  final RepeatType repeat;
  final int? repeatIntervalMinutes;
}
