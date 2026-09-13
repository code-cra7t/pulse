import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';

void main() {
  test('defaults stay at suggest for backward compatibility', () {
    expect(AutomationPreferences.defaults().level, AutomationLevel.suggest);
  });

  test('parses every supported automation level', () {
    for (final level in AutomationLevel.values) {
      final parsed = AutomationPreferences.fromMap({'level': level.name});
      expect(parsed.level, level);
    }
  });

  test('unknown automation level falls back to suggest', () {
    final parsed = AutomationPreferences.fromMap({'level': 'unbounded'});
    expect(parsed.level, AutomationLevel.suggest);
  });

  test('missing automation map falls back to suggest', () {
    expect(AutomationPreferences.fromMap(null).level, AutomationLevel.suggest);
  });

  test('serializes only the stable level field', () {
    const preferences = AutomationPreferences(level: AutomationLevel.approval);
    expect(preferences.toMap(), {'level': 'approval'});
  });
}
