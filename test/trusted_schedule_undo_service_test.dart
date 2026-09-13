import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_automation_audit_store.dart';
import 'package:pulse/core/offline/offline_schedule_block_store.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/data/trusted_schedule_undo_service.dart';
import 'package:pulse/features/automation/models/automation_audit_entry.dart';
import 'package:pulse/features/scheduling/data/local_schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineScheduleBlockStore blockStore;
  late OfflineAutomationAuditStore auditStore;
  late LocalScheduleBlocksRepository repository;

  setUp(() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    blockStore = OfflineScheduleBlockStore(
      openDatabase: () =>
          databaseFactoryMemory.openDatabase('undo-blocks-$stamp.db'),
    );
    auditStore = OfflineAutomationAuditStore(
      openDatabase: () =>
          databaseFactoryMemory.openDatabase('undo-audit-$stamp.db'),
    );
    repository = LocalScheduleBlocksRepository(blockStore);
  });

  tearDown(() async {
    await blockStore.dispose();
    await auditStore.dispose();
  });

  test('undo restores the original slot and marks the audit undone', () async {
    final now = DateTime(2026, 9, 13, 12);
    final original = await _accept(repository, DateTime(2026, 9, 14, 9));
    final moved = await repository.rescheduleBlock(
      block: original,
      startsAt: DateTime(2026, 9, 14, 11),
      endsAt: DateTime(2026, 9, 14, 12),
    );
    final entry = _entry(original: original, moved: moved, executedAt: now);
    await auditStore.upsert(entry);

    final result = await _service(
      repository,
      auditStore,
      linked: false,
    ).undo(userId: 'user', entry: entry, now: now);

    final restored = (await repository.readBlocks('user')).single;
    expect(restored.startsAt, original.startsAt);
    expect(restored.endsAt, original.endsAt);
    expect(result.status, AutomationAuditStatus.undone);
    expect(result.undoneAt, isNotNull);
    expect(
      (await auditStore.readEntries('user')).single.status,
      AutomationAuditStatus.undone,
    );
  });

  test('undo rejects a block that changed after the trusted move', () async {
    final now = DateTime(2026, 9, 13, 12);
    final original = await _accept(repository, DateTime(2026, 9, 14, 9));
    final moved = await repository.rescheduleBlock(
      block: original,
      startsAt: DateTime(2026, 9, 14, 11),
      endsAt: DateTime(2026, 9, 14, 12),
    );
    final entry = _entry(original: original, moved: moved, executedAt: now);
    await repository.rescheduleBlock(
      block: moved,
      startsAt: DateTime(2026, 9, 14, 13),
      endsAt: DateTime(2026, 9, 14, 14),
    );

    await expectLater(
      _service(
        repository,
        auditStore,
        linked: false,
      ).undo(userId: 'user', entry: entry, now: now),
      throwsStateError,
    );
  });

  test('undo refuses a block that became calendar linked', () async {
    final now = DateTime(2026, 9, 13, 12);
    final original = await _accept(repository, DateTime(2026, 9, 14, 9));
    final moved = await repository.rescheduleBlock(
      block: original,
      startsAt: DateTime(2026, 9, 14, 11),
      endsAt: DateTime(2026, 9, 14, 12),
    );
    final entry = _entry(original: original, moved: moved, executedAt: now);

    await expectLater(
      _service(
        repository,
        auditStore,
        linked: true,
      ).undo(userId: 'user', entry: entry, now: now),
      throwsStateError,
    );
    expect(
      (await repository.readBlocks('user')).single.startsAt,
      moved.startsAt,
    );
  });

  test('undo rejects an original slot that is already in the past', () async {
    final now = DateTime(2026, 9, 14, 10, 30);
    final original = await _accept(repository, DateTime(2026, 9, 14, 9));
    final moved = await repository.rescheduleBlock(
      block: original,
      startsAt: DateTime(2026, 9, 14, 11),
      endsAt: DateTime(2026, 9, 14, 12),
    );
    final entry = _entry(
      original: original,
      moved: moved,
      executedAt: DateTime(2026, 9, 13, 12),
    );

    await expectLater(
      _service(
        repository,
        auditStore,
        linked: false,
      ).undo(userId: 'user', entry: entry, now: now),
      throwsStateError,
    );
  });

  test(
    'undo conflict keeps the trusted move and records the failure',
    () async {
      final now = DateTime(2026, 9, 13, 12);
      final original = await _accept(repository, DateTime(2026, 9, 14, 9));
      final moved = await repository.rescheduleBlock(
        block: original,
        startsAt: DateTime(2026, 9, 14, 11),
        endsAt: DateTime(2026, 9, 14, 12),
      );
      final entry = _entry(original: original, moved: moved, executedAt: now);
      await auditStore.upsert(entry);
      await repository.acceptProposal(
        userId: 'user',
        proposal: ScheduleProposal(
          id: 'other',
          taskId: 'other',
          title: 'Other task',
          startsAt: original.startsAt,
          endsAt: original.endsAt,
          reason: 'Occupy old slot',
          score: 1,
          assumedEffort: false,
        ),
      );

      await expectLater(
        _service(
          repository,
          auditStore,
          linked: false,
        ).undo(userId: 'user', entry: entry, now: now),
        throwsStateError,
      );

      final current = (await repository.readBlocks(
        'user',
      )).firstWhere((block) => block.id == moved.id);
      expect(current.startsAt, moved.startsAt);
      final audit = (await auditStore.readEntries(
        'user',
      )).firstWhere((item) => item.id == entry.id);
      expect(audit.status, AutomationAuditStatus.succeeded);
      expect(audit.undoError, contains('no longer free'));
    },
  );
}

TrustedScheduleUndoService _service(
  LocalScheduleBlocksRepository repository,
  OfflineAutomationAuditStore auditStore, {
  required bool linked,
}) {
  return TrustedScheduleUndoService(
    scheduleBlocks: repository,
    auditStore: auditStore,
    isCalendarLinked: (_) async => linked,
  );
}

Future<ScheduleBlock> _accept(
  LocalScheduleBlocksRepository repository,
  DateTime start,
) {
  return repository.acceptProposal(
    userId: 'user',
    proposal: ScheduleProposal(
      id: 'proposal',
      taskId: 'task',
      title: 'Study',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      reason: 'Test',
      score: 1,
      assumedEffort: false,
    ),
  );
}

AutomationAuditEntry _entry({
  required ScheduleBlock original,
  required ScheduleBlock moved,
  required DateTime executedAt,
}) {
  return AutomationAuditEntry(
    id: 'audit-${moved.id}',
    userId: 'user',
    action: AutomationActionKind.localScheduleMove,
    issueId: 'issue',
    blockId: moved.id,
    title: moved.title,
    reason: 'Calendar conflict',
    fromStartsAt: original.startsAt,
    fromEndsAt: original.endsAt,
    toStartsAt: moved.startsAt,
    toEndsAt: moved.endsAt,
    executedAt: executedAt,
    status: AutomationAuditStatus.succeeded,
  );
}
