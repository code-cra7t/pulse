import '../models/parsed_reminder.dart';
import 'smart_reminder_parser.dart';

class SmartReminderParserExamples {
  static List<ParsedReminder?> buildExamples() {
    final parser = SmartReminderParser();
    final reference = DateTime(2026, 4, 5, 14, 30);

    return [
      parser.parse('remind me tomorrow 5pm', now: reference),
      parser.parse('today 17:00', now: reference),
      parser.parse('next monday 9am', now: reference),
      parser.parse('in 3 hours', now: reference),
      parser.parse('5pm', now: reference),
    ];
  }
}
