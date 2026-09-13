import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';

void main() {
  test('defaults are valid but remain unconfigured', () {
    final preferences = SchedulingPreferences.defaults();

    expect(preferences.isValid, isTrue);
    expect(preferences.isConfigured, isFalse);
    expect(preferences.isEnabledOn(DateTime(2026, 9, 14)), isTrue);
  });

  test('planning preferences round-trip through settings map', () {
    final preferences = SchedulingPreferences.defaults().copyWith(
      isConfigured: true,
      dayStartMinutes: 9 * 60,
      dayEndMinutes: 19 * 60,
      availableWeekdays: const [1, 3, 5, 6],
      minimumBlockMinutes: 30,
      preferredBlockMinutes: 60,
      breakMinutes: 10,
      maxFocusMinutesPerDay: 300,
      defaultTaskMinutes: 45,
      protectLunch: true,
      lunchStartMinutes: 12 * 60,
      lunchEndMinutes: 13 * 60,
    );

    final restored = SchedulingPreferences.fromMap(preferences.toMap());

    expect(restored.isConfigured, isTrue);
    expect(restored.dayStartMinutes, 540);
    expect(restored.dayEndMinutes, 1140);
    expect(restored.availableWeekdays, [1, 3, 5, 6]);
    expect(restored.preferredBlockMinutes, 60);
    expect(restored.defaultTaskMinutes, 45);
    expect(restored.protectLunch, isTrue);
  });

  test('invalid stored values safely fall back to defaults', () {
    final restored = SchedulingPreferences.fromMap({
      'isConfigured': true,
      'dayStartMinutes': 1000,
      'dayEndMinutes': 900,
    });

    expect(restored.isConfigured, isFalse);
    expect(restored.isValid, isTrue);
  });
}
