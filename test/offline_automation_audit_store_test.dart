import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_automation_audit_store.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_audit_entry.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineAutomationAuditStore store;

  setUp(() {
    final databaseName =
        'jotcue-automation-audit-${DateTime.now().microsecondsSinceEpoch}.db';
    store = OfflineAutomationAuditStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
      maxEntriesPerUser: 2,
    );
  });

  tearDown(() async {
    await store.dispose();
  });

  test('upserts and emits automation activity newest first', () async {
    await store.upsert(_entry('one', DateTime(2026, 9, 13, 10)));
    await store.upsert(_entry('two', DateTime(2026, 9, 13, 11)));

    final entries = await store.readEntries('user');

    expect(entries.map((entry) => entry.id), ['two', 'one']);
  });

  test('trims older activity and clears one user', () async {
    await store.upsert(_entry('one', DateTime(2026, 9, 13, 9)));
    await store.upsert(_entry('two', DateTime(2026, 9, 13, 10)));
    await store.upsert(_entry('three', DateTime(2026, 9, 13, 11)));

    expect((await store.readEntries('user')).map((entry) => entry.id), [
      'three',
      'two',
    ]);

    await store.clearUser('user');
    expect(await store.readEntries('user'), isEmpty);
  });

  test(
    'clears older history but preserves recent cooldown and pending entries',
    () async {
      await store.dispose();
      final databaseName =
          'jotcue-automation-retention-${DateTime.now().microsecondsSinceEpoch}.db';
      store = OfflineAutomationAuditStore(
        openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
        maxEntriesPerUser: 10,
      );
      final now = DateTime(2026, 9, 13, 12);
      await store.upsert(_entry('old', now.subtract(const Duration(hours: 2))));
      await store.upsert(
        _entry('recent', now.subtract(const Duration(minutes: 10))),
      );
      await store.upsert(
        _entry(
          'pending',
          now.subtract(const Duration(hours: 3)),
        ).copyWith(status: AutomationAuditStatus.pending),
      );

      final removed = await store.clearOlderEntries('user', now: now);
      final entries = await store.readEntries('user');

      expect(removed, 1);
      expect(
        entries.map((entry) => entry.id),
        containsAll(['recent', 'pending']),
      );
      expect(entries.map((entry) => entry.id), isNot(contains('old')));
    },
  );
}

AutomationAuditEntry _entry(String id, DateTime time) {
  return AutomationAuditEntry(
    id: id,
    userId: 'user',
    action: AutomationActionKind.localScheduleMove,
    issueId: 'issue-$id',
    blockId: 'block-$id',
    title: 'Task $id',
    reason: 'Test',
    fromStartsAt: time,
    fromEndsAt: time.add(const Duration(hours: 1)),
    toStartsAt: time.add(const Duration(hours: 2)),
    toEndsAt: time.add(const Duration(hours: 3)),
    executedAt: time,
    status: AutomationAuditStatus.succeeded,
  );
}
