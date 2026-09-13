import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_ai_assistant_store.dart';
import 'package:pulse/features/assistant/models/ai_assistant_preferences.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test('device AI preference persists and clears back to local-only', () async {
    final db = await databaseFactoryMemory.openDatabase('ai-assistant-test.db');
    final store = OfflineAiAssistantStore(openDatabase: () async => db);

    expect((await store.readPreferences()).mode, AiAssistantMode.localOnly);
    await store.writePreferences(
      const AiAssistantPreferences(mode: AiAssistantMode.hybrid),
    );
    expect((await store.readPreferences()).mode, AiAssistantMode.hybrid);

    await store.clearDevice();
    expect((await store.readPreferences()).mode, AiAssistantMode.localOnly);
    await store.dispose();
  });
}
