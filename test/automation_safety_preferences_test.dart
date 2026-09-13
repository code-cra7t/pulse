import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/automation/models/automation_safety_preferences.dart';

void main() {
  test('defaults keep trusted execution unpaused with no exclusions', () {
    const preferences = AutomationSafetyPreferences();

    expect(preferences.paused, isFalse);
    expect(preferences.excludedTaskIds, isEmpty);
    expect(preferences.excludedProjectIds, isEmpty);
    expect(preferences.exclusionCount, 0);
  });

  test('local map round-trip preserves pause and exclusions', () {
    const preferences = AutomationSafetyPreferences(
      paused: true,
      excludedTaskIds: {'task-b', 'task-a'},
      excludedProjectIds: {'project-a'},
    );

    final restored = AutomationSafetyPreferences.fromLocalMap(
      preferences.toLocalMap(),
    );

    expect(restored.paused, isTrue);
    expect(restored.excludedTaskIds, {'task-a', 'task-b'});
    expect(restored.excludedProjectIds, {'project-a'});
    expect(restored.exclusionCount, 3);
  });

  test('invalid local data fails open for controls but never invents IDs', () {
    final restored = AutomationSafetyPreferences.fromLocalMap({
      'paused': 'yes',
      'excludedTaskIds': [null, '', 42, 'task-a'],
      'excludedProjectIds': 'project-a',
    });

    expect(restored.paused, isFalse);
    expect(restored.excludedTaskIds, {'task-a'});
    expect(restored.excludedProjectIds, isEmpty);
  });
}
