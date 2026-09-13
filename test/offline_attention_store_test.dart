import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_attention_store.dart';
import 'package:pulse/features/attention/models/attention_preferences.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test('attention preferences and delivery state persist and clear', () async {
    final db = await databaseFactoryMemory.openDatabase('attention-test.db');
    final store = OfflineAttentionStore(openDatabase: () async => db);
    const prefs = AttentionPreferences(enabled: false, morningMinutes: 555);
    await store.writePreferences('u1', prefs);
    expect(
      (await store.readPreferences('u1')).toLocalMap(),
      prefs.toLocalMap(),
    );

    final state = AttentionDeliveryState(
      fingerprint: 'abc',
      notificationIds: const [1, 2],
      lastIssueSignature: 'issue',
      lastIssueAlertAt: DateTime(2026, 9, 13),
    );
    await store.writeDelivery('u1', state);
    expect((await store.readDelivery('u1')).notificationIds, [1, 2]);

    await store.clearUser('u1');
    expect((await store.readPreferences('u1')).enabled, isTrue);
    expect((await store.readDelivery('u1')).notificationIds, isEmpty);
    await store.dispose();
  });
}
