import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/attention/models/attention_preferences.dart';

void main() {
  test('overnight quiet hours cover late night and early morning', () {
    const prefs = AttentionPreferences();
    expect(prefs.isQuiet(DateTime(2026, 9, 13, 23)), isTrue);
    expect(prefs.isQuiet(DateTime(2026, 9, 14, 6, 59)), isTrue);
    expect(prefs.isQuiet(DateTime(2026, 9, 14, 7)), isFalse);
    expect(prefs.isQuiet(DateTime(2026, 9, 13, 12)), isFalse);
  });

  test('nextAllowed defers late-night cue to next quiet end', () {
    const prefs = AttentionPreferences();
    expect(
      prefs.nextAllowed(DateTime(2026, 9, 13, 23, 30)),
      DateTime(2026, 9, 14, 7),
    );
  });

  test('nextAllowed defers early-morning cue to same-day quiet end', () {
    const prefs = AttentionPreferences();
    expect(
      prefs.nextAllowed(DateTime(2026, 9, 13, 6, 30)),
      DateTime(2026, 9, 13, 7),
    );
  });

  test('local map round-trips', () {
    const original = AttentionPreferences(
      enabled: false,
      morningMinutes: 540,
      closingMinutes: 1230,
      quietStartMinutes: 1260,
      quietEndMinutes: 480,
    );
    expect(
      AttentionPreferences.fromLocalMap(original.toLocalMap()).toLocalMap(),
      original.toLocalMap(),
    );
  });
}
