import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/assistant/models/ai_assistant_preferences.dart';

void main() {
  test('AI assistant defaults to local only and round-trips hybrid mode', () {
    expect(
      AiAssistantPreferences.fromLocalMap(null).mode,
      AiAssistantMode.localOnly,
    );
    const hybrid = AiAssistantPreferences(mode: AiAssistantMode.hybrid);
    expect(
      AiAssistantPreferences.fromLocalMap(hybrid.toLocalMap()).mode,
      AiAssistantMode.hybrid,
    );
  });

  test('unknown stored mode fails closed to local only', () {
    expect(
      AiAssistantPreferences.fromLocalMap(const {'mode': 'future-mode'}).mode,
      AiAssistantMode.localOnly,
    );
  });
}
