import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/reminders/data/assistant_plan_parser.dart';

void main() {
  final parser = AssistantPlanParser();

  test('detects clear numbered plans', () {
    final suggestion = parser.parse('''
Launch checklist
1. Prepare the copy
2. Send it for review
3. Publish the announcement
''');

    expect(suggestion, isNotNull);
    expect(suggestion!.steps.map((step) => step.text), [
      'Prepare the copy',
      'Send it for review',
      'Publish the announcement',
    ]);
  });

  test('does not turn ordinary prose into a plan', () {
    expect(parser.parse('Think about the launch tomorrow.'), isNull);
  });
}
