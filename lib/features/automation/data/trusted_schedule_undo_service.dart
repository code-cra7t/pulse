import '../../../core/offline/offline_automation_audit_store.dart';
import '../../scheduling/data/schedule_blocks_repository.dart';
import '../../scheduling/models/schedule_block.dart';
import '../models/automation_audit_entry.dart';
import 'trusted_schedule_executor.dart';

class TrustedScheduleUndoService {
  const TrustedScheduleUndoService({
    required ScheduleBlocksRepository scheduleBlocks,
    required OfflineAutomationAuditStore auditStore,
    required CalendarLinkChecker isCalendarLinked,
  }) : _scheduleBlocks = scheduleBlocks,
       _auditStore = auditStore,
       _isCalendarLinked = isCalendarLinked;

  final ScheduleBlocksRepository _scheduleBlocks;
  final OfflineAutomationAuditStore _auditStore;
  final CalendarLinkChecker _isCalendarLinked;

  Future<AutomationAuditEntry> undo({
    required String userId,
    required AutomationAuditEntry entry,
    required DateTime now,
  }) async {
    if (entry.userId != userId ||
        entry.status != AutomationAuditStatus.succeeded) {
      throw StateError('This trusted move is no longer undoable.');
    }
    if (!entry.fromStartsAt.isAfter(now) ||
        !entry.fromEndsAt.isAfter(entry.fromStartsAt)) {
      throw StateError('The original time has already passed.');
    }

    final blocks = await _scheduleBlocks.readBlocks(userId);
    ScheduleBlock? block;
    for (final item in blocks) {
      if (item.id == entry.blockId) {
        block = item;
        break;
      }
    }
    if (block == null ||
        block.status != ScheduleBlockStatus.scheduled ||
        block.startsAt != entry.toStartsAt ||
        block.endsAt != entry.toEndsAt) {
      throw StateError(
        'This block changed after JotCue moved it. Refresh before undoing.',
      );
    }
    final currentBlock = block;

    bool linked;
    try {
      linked = await _isCalendarLinked(currentBlock.id);
    } catch (_) {
      throw StateError(
        'JotCue could not verify the calendar link, so undo was not applied.',
      );
    }
    if (linked) {
      throw StateError(
        'Remove or update the linked calendar entry before undoing this move.',
      );
    }

    final pending = entry.copyWith(
      status: AutomationAuditStatus.undoPending,
      undoRequestedAt: now,
      undoError: null,
    );
    await _auditStore.upsert(pending);

    try {
      await _scheduleBlocks.rescheduleBlock(
        block: currentBlock,
        startsAt: entry.fromStartsAt,
        endsAt: entry.fromEndsAt,
      );
    } catch (error) {
      await _auditStore.upsert(
        entry.copyWith(undoRequestedAt: now, undoError: error.toString()),
      );
      rethrow;
    }

    final undone = pending.copyWith(
      status: AutomationAuditStatus.undone,
      undoneAt: now,
      undoError: null,
    );
    try {
      await _auditStore.upsert(undone);
    } catch (_) {
      // The block is already restored. Keep the last durable audit state as
      // undoPending rather than risking a second automatic schedule mutation.
      rethrow;
    }

    return undone;
  }
}
