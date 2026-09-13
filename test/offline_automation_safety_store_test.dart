import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_automation_safety_store.dart';
import 'package:pulse/features/automation/models/automation_safety_preferences.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineAutomationSafetyStore store;

  setUp(() {
    final databaseName =
        'jotcue-automation-safety-${DateTime.now().microsecondsSinceEpoch}.db';
    store = OfflineAutomationSafetyStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
    );
  });

  tearDown(() async {
    await store.dispose();
  });

  test('writes and reads device-local safety preferences', () async {
    const preferences = AutomationSafetyPreferences(
      paused: true,
      excludedTaskIds: {'task-a'},
      excludedProjectIds: {'project-a'},
    );

    await store.writePreferences('user', preferences);
    final restored = await store.readPreferences('user');

    expect(restored.paused, isTrue);
    expect(restored.excludedTaskIds, {'task-a'});
    expect(restored.excludedProjectIds, {'project-a'});
  });

  test('clearUser resets one user to safe defaults', () async {
    await store.writePreferences(
      'user',
      const AutomationSafetyPreferences(paused: true),
    );
    await store.writePreferences(
      'other',
      const AutomationSafetyPreferences(excludedTaskIds: {'task'}),
    );

    await store.clearUser('user');

    expect((await store.readPreferences('user')).paused, isFalse);
    expect((await store.readPreferences('other')).excludedTaskIds, {'task'});
  });
}
