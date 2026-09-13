import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_automation_audit_store.dart';
import 'package:pulse/core/offline/offline_schedule_block_store.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/data/trusted_schedule_executor.dart';
import 'package:pulse/features/automation/models/automation_audit_entry.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';
import 'package:pulse/features/scheduling/data/local_schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:pulse/features/tasks/models/task.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineScheduleBlockStore blockStore;
  late OfflineAutomationAuditStore auditStore;
  late LocalScheduleBlocksRepository repository;

  setUp(() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    blockStore = OfflineScheduleBlockStore(
      openDatabase: () =>
          databaseFactoryMemory.openDatabase('blocks-$stamp.db'),
    );
    auditStore = OfflineAutomationAuditStore(
      openDatabase: () => databaseFactoryMemory.openDatabase('audit-$stamp.db'),
    );
    repository = LocalScheduleBlocksRepository(blockStore);
  });

  tearDown(() async {
    await blockStore.dispose();
    await auditStore.dispose();
  });

  test(
    'trusted mode moves one future flexible unlinked proposal block',
    () async {
      final now = DateTime(2026, 9, 13, 12);
      final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
      final executor = _executor(repository, auditStore, linked: false);

      final entry = await executor.executeNext(
        userId: 'user',
        preferences: const AutomationPreferences(
          level: AutomationLevel.trusted,
        ),
        overview: _overview(now, [
          _issue(
            block,
            DateTime(2026, 9, 14, 11),
            ReplanningIssueKind.calendarConflict,
          ),
        ]),
        tasks: [_task('one')],
        now: now,
      );

      expect(entry, isNotNull);
      expect(entry!.status, AutomationAuditStatus.succeeded);
      expect(
        (await repository.readBlocks('user')).single.startsAt,
        DateTime(2026, 9, 14, 11),
      );
      expect(
        (await auditStore.readEntries('user')).single.status,
        AutomationAuditStatus.succeeded,
      );
    },
  );

  test('suggest mode never executes', () async {
    final now = DateTime(2026, 9, 13, 12);
    final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
    final executor = _executor(repository, auditStore, linked: false);

    final entry = await executor.executeNext(
      userId: 'user',
      preferences: const AutomationPreferences(level: AutomationLevel.suggest),
      overview: _overview(now, [
        _issue(
          block,
          DateTime(2026, 9, 14, 11),
          ReplanningIssueKind.calendarConflict,
        ),
      ]),
      tasks: [_task('one')],
      now: now,
    );

    expect(entry, isNull);
    expect(
      (await repository.readBlocks('user')).single.startsAt,
      DateTime(2026, 9, 14, 9),
    );
    expect(await auditStore.readEntries('user'), isEmpty);
  });

  test('linked calendar block fails closed and stays put', () async {
    final now = DateTime(2026, 9, 13, 12);
    final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
    final executor = _executor(repository, auditStore, linked: true);

    final entry = await executor.executeNext(
      userId: 'user',
      preferences: const AutomationPreferences(level: AutomationLevel.trusted),
      overview: _overview(now, [
        _issue(
          block,
          DateTime(2026, 9, 14, 11),
          ReplanningIssueKind.calendarConflict,
        ),
      ]),
      tasks: [_task('one')],
      now: now,
    );

    expect(entry, isNull);
    expect(
      (await repository.readBlocks('user')).single.startsAt,
      DateTime(2026, 9, 14, 9),
    );
  });

  test('non-flexible task is never trusted-moved', () async {
    final now = DateTime(2026, 9, 13, 12);
    final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));

    final entry = await _executor(repository, auditStore, linked: false)
        .executeNext(
          userId: 'user',
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          overview: _overview(now, [
            _issue(
              block,
              DateTime(2026, 9, 14, 11),
              ReplanningIssueKind.outsideAvailability,
            ),
          ]),
          tasks: [_task('one', flexible: false)],
          now: now,
        );

    expect(entry, isNull);
  });

  test('past block review is never trusted-moved', () async {
    final now = DateTime(2026, 9, 14, 12);
    final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));

    final entry = await _executor(repository, auditStore, linked: false)
        .executeNext(
          userId: 'user',
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          overview: _overview(now, [
            _issue(
              block,
              DateTime(2026, 9, 15, 9),
              ReplanningIssueKind.pastBlockReview,
            ),
          ]),
          tasks: [_task('one')],
          now: now,
        );

    expect(entry, isNull);
  });

  test('stale block snapshot is skipped', () async {
    final now = DateTime(2026, 9, 13, 12);
    final original = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
    await repository.rescheduleBlock(
      block: original,
      startsAt: DateTime(2026, 9, 14, 10),
      endsAt: DateTime(2026, 9, 14, 11),
    );

    final entry = await _executor(repository, auditStore, linked: false)
        .executeNext(
          userId: 'user',
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          overview: _overview(now, [
            _issue(
              original,
              DateTime(2026, 9, 14, 12),
              ReplanningIssueKind.calendarConflict,
            ),
          ]),
          tasks: [_task('one')],
          now: now,
        );

    expect(entry, isNull);
    expect(
      (await repository.readBlocks('user')).single.startsAt,
      DateTime(2026, 9, 14, 10),
    );
  });

  test('executes at most one move per fresh snapshot', () async {
    final now = DateTime(2026, 9, 13, 12);
    final first = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
    final second = await _accept(repository, 'two', DateTime(2026, 9, 14, 13));

    final entry = await _executor(repository, auditStore, linked: false)
        .executeNext(
          userId: 'user',
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          overview: _overview(now, [
            _issue(
              first,
              DateTime(2026, 9, 14, 11),
              ReplanningIssueKind.calendarConflict,
            ),
            _issue(
              second,
              DateTime(2026, 9, 14, 15),
              ReplanningIssueKind.outsideAvailability,
            ),
          ]),
          tasks: [_task('one'), _task('two')],
          now: now,
        );

    expect(entry?.blockId, first.id);
    final blocks = await repository.readBlocks('user');
    expect(
      blocks.firstWhere((block) => block.id == first.id).startsAt,
      DateTime(2026, 9, 14, 11),
    );
    expect(
      blocks.firstWhere((block) => block.id == second.id).startsAt,
      DateTime(2026, 9, 14, 13),
    );
    expect(await auditStore.readEntries('user'), hasLength(1));
  });

  test('user-created block is never trusted-moved', () async {
    final now = DateTime(2026, 9, 13, 12);
    final block = ScheduleBlock(
      id: 'manual',
      userId: 'user',
      taskId: 'one',
      title: 'Manual block',
      startsAt: DateTime(2026, 9, 14, 9),
      endsAt: DateTime(2026, 9, 14, 10),
      source: ScheduleBlockSource.user,
      createdAt: now,
      updatedAt: now,
    );
    await blockStore.upsert(block);

    final entry = await _executor(repository, auditStore, linked: false)
        .executeNext(
          userId: 'user',
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          overview: _overview(now, [
            _issue(
              block,
              DateTime(2026, 9, 14, 11),
              ReplanningIssueKind.calendarConflict,
            ),
          ]),
          tasks: [_task('one')],
          now: now,
        );

    expect(entry, isNull);
    expect(
      (await repository.readBlocks('user')).single.startsAt,
      DateTime(2026, 9, 14, 9),
    );
  });

  test('calendar-link verification failure skips the move', () async {
    final now = DateTime(2026, 9, 13, 12);
    final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
    final executor = TrustedScheduleExecutor(
      policy: const AutomationPolicy(),
      scheduleBlocks: repository,
      auditStore: auditStore,
      isCalendarLinked: (_) => Future.error(StateError('bridge unavailable')),
    );

    final entry = await executor.executeNext(
      userId: 'user',
      preferences: const AutomationPreferences(level: AutomationLevel.trusted),
      overview: _overview(now, [
        _issue(
          block,
          DateTime(2026, 9, 14, 11),
          ReplanningIssueKind.calendarConflict,
        ),
      ]),
      tasks: [_task('one')],
      now: now,
    );

    expect(entry, isNull);
    expect(await auditStore.readEntries('user'), isEmpty);
  });

  test(
    'failed schedule mutation is retained as a failed audit attempt',
    () async {
      final now = DateTime(2026, 9, 13, 12);
      final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
      await _accept(repository, 'two', DateTime(2026, 9, 14, 11));
      final executor = _executor(repository, auditStore, linked: false);

      await expectLater(
        executor.executeNext(
          userId: 'user',
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          overview: _overview(now, [
            _issue(
              block,
              DateTime(2026, 9, 14, 11, 30),
              ReplanningIssueKind.calendarConflict,
            ),
          ]),
          tasks: [_task('one'), _task('two')],
          now: now,
        ),
        throwsStateError,
      );

      final audit = (await auditStore.readEntries('user')).single;
      expect(audit.status, AutomationAuditStatus.failed);
      expect(audit.error, contains('no longer free'));
    },
  );

  test('audit-store failure prevents the schedule mutation', () async {
    final now = DateTime(2026, 9, 13, 12);
    final block = await _accept(repository, 'one', DateTime(2026, 9, 14, 9));
    final brokenAudit = OfflineAutomationAuditStore(
      openDatabase: () => Future.error(StateError('disk unavailable')),
    );
    final executor = _executor(repository, brokenAudit, linked: false);

    await expectLater(
      executor.executeNext(
        userId: 'user',
        preferences: const AutomationPreferences(
          level: AutomationLevel.trusted,
        ),
        overview: _overview(now, [
          _issue(
            block,
            DateTime(2026, 9, 14, 11),
            ReplanningIssueKind.calendarConflict,
          ),
        ]),
        tasks: [_task('one')],
        now: now,
      ),
      throwsStateError,
    );

    expect(
      (await repository.readBlocks('user')).single.startsAt,
      DateTime(2026, 9, 14, 9),
    );
  });
}

TrustedScheduleExecutor _executor(
  LocalScheduleBlocksRepository repository,
  OfflineAutomationAuditStore auditStore, {
  required bool linked,
}) {
  return TrustedScheduleExecutor(
    policy: const AutomationPolicy(),
    scheduleBlocks: repository,
    auditStore: auditStore,
    isCalendarLinked: (_) async => linked,
  );
}

Future<ScheduleBlock> _accept(
  LocalScheduleBlocksRepository repository,
  String taskId,
  DateTime start,
) {
  return repository.acceptProposal(
    userId: 'user',
    proposal: ScheduleProposal(
      id: 'proposal-$taskId',
      taskId: taskId,
      title: 'Task $taskId',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      reason: 'Test',
      score: 1,
      assumedEffort: false,
    ),
  );
}

Task _task(String id, {bool flexible = true}) {
  return Task(
    id: id,
    userId: 'user',
    title: 'Task $id',
    isCompleted: false,
    sourceNoteId: 'note-$id',
    sourceLineIndex: 0,
    isFlexible: flexible,
  );
}

ReplanningOverview _overview(DateTime now, List<ReplanningIssue> issues) {
  return ReplanningOverview(
    generatedAt: now,
    horizonEnd: now.add(const Duration(days: 7)),
    issues: issues,
    calendarConflictsChecked: true,
  );
}

ReplanningIssue _issue(
  ScheduleBlock block,
  DateTime target,
  ReplanningIssueKind kind,
) {
  return ReplanningIssue(
    id: '${kind.name}-${block.id}',
    kind: kind,
    title: block.title,
    message: 'Move this block because the plan changed.',
    taskId: block.taskId,
    projectId: block.projectId,
    block: block,
    suggestion: ReplanningSuggestion(
      startsAt: target,
      endsAt: target.add(block.duration),
    ),
  );
}
