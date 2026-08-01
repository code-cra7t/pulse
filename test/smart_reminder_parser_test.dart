import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/reminders/data/smart_reminder_parser.dart';

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
}
