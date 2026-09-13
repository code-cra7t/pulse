import '../../../core/offline/offline_automation_audit_store.dart';
import '../../scheduling/data/schedule_blocks_repository.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../models/automation_audit_entry.dart';
import '../models/automation_preferences.dart';
import '../models/automation_safety_preferences.dart';
import 'automation_policy.dart';

typedef CalendarLinkChecker = Future<bool> Function(String blockId);

/// Executes at most one low-risk trusted schedule move from a fresh replanning
/// snapshot. Callers must recompute replanning before requesting another move.
class TrustedScheduleExecutor {
  const TrustedScheduleExecutor({
    required AutomationPolicy policy,
    required ScheduleBlocksRepository scheduleBlocks,
    required OfflineAutomationAuditStore auditStore,
    required CalendarLinkChecker isCalendarLinked,
    this.cooldown = const Duration(minutes: 30),
  }) : _policy = policy,
       _scheduleBlocks = scheduleBlocks,
       _auditStore = auditStore,
       _isCalendarLinked = isCalendarLinked;

  static const Duration defaultCooldown = Duration(minutes: 30);

  final AutomationPolicy _policy;
  final ScheduleBlocksRepository _scheduleBlocks;
  final OfflineAutomationAuditStore _auditStore;
  final CalendarLinkChecker _isCalendarLinked;
  final Duration cooldown;

  Future<AutomationAuditEntry?> executeNext({
    required String userId,
    required AutomationPreferences preferences,
    required ReplanningOverview overview,
    required List<Task> tasks,
    required DateTime now,
    AutomationSafetyPreferences safety = const AutomationSafetyPreferences(),
  }) async {
    final decision = _policy.evaluate(
      preferences: preferences,
      action: AutomationActionKind.localScheduleMove,
    );
    if (decision != AutomationDecision.trustedEligible || safety.paused) {
      return null;
    }

    final taskById = <String, Task>{for (final task in tasks) task.id: task};
    final currentBlocks = await _scheduleBlocks.readBlocks(userId);
    final currentById = <String, ScheduleBlock>{
      for (final block in currentBlocks) block.id: block,
    };
    // Reading the local audit log is part of the safety decision. If this
    // fails, execution fails closed rather than bypassing cooldown protection.
    final auditEntries = await _auditStore.readEntries(userId);

    for (final issue in overview.issues) {
      if (!_trustedIssueKind(issue.kind)) {
        continue;
      }
      final proposedBlock = issue.block;
      final suggestion = issue.suggestion;
      if (proposedBlock == null || suggestion == null) {
        continue;
      }

      final block = currentById[proposedBlock.id];
      if (block == null || !_sameBlockState(block, proposedBlock)) {
        continue;
      }
      if (block.userId != userId ||
          block.status != ScheduleBlockStatus.scheduled ||
          block.source != ScheduleBlockSource.proposal ||
          !block.startsAt.isAfter(now)) {
        continue;
      }

      final task = taskById[block.taskId];
      if (task == null || !task.isFlexible || task.isCompleted) {
        continue;
      }
      if (safety.excludesTask(task.id) ||
          safety.excludesProject(task.projectId)) {
        continue;
      }
      if (_isCoolingDown(block.id, auditEntries, now, cooldown)) {
        continue;
      }
      if (!suggestion.endsAt.isAfter(suggestion.startsAt) ||
          !suggestion.startsAt.isAfter(now)) {
        continue;
      }

      bool linked;
      try {
        linked = await _isCalendarLinked(block.id);
      } catch (_) {
        // Failing closed avoids desynchronizing a possibly linked calendar copy.
        continue;
      }
      if (linked) {
        continue;
      }

      final startedAt = DateTime.now();
      var entry = AutomationAuditEntry(
        id: '${startedAt.microsecondsSinceEpoch}-${block.id}',
        userId: userId,
        action: AutomationActionKind.localScheduleMove,
        issueId: issue.id,
        blockId: block.id,
        title: block.title,
        reason: issue.message,
        fromStartsAt: block.startsAt,
        fromEndsAt: block.endsAt,
        toStartsAt: suggestion.startsAt,
        toEndsAt: suggestion.endsAt,
        executedAt: startedAt,
        status: AutomationAuditStatus.pending,
      );

      // If audit persistence fails, trusted execution fails closed and the
      // schedule remains untouched.
      await _auditStore.upsert(entry);
      try {
        await _scheduleBlocks.rescheduleBlock(
          block: block,
          startsAt: suggestion.startsAt,
          endsAt: suggestion.endsAt,
        );
        entry = entry.copyWith(status: AutomationAuditStatus.succeeded);
        await _auditStore.upsert(entry);
        return entry;
      } catch (error) {
        await _auditStore.upsert(
          entry.copyWith(
            status: AutomationAuditStatus.failed,
            error: error.toString(),
          ),
        );
        rethrow;
      }
    }

    return null;
  }
}

bool _trustedIssueKind(ReplanningIssueKind kind) {
  return kind == ReplanningIssueKind.calendarConflict ||
      kind == ReplanningIssueKind.outsideAvailability ||
      kind == ReplanningIssueKind.urgentCapacity;
}

bool _sameBlockState(ScheduleBlock current, ScheduleBlock proposed) {
  return current.id == proposed.id &&
      current.taskId == proposed.taskId &&
      current.startsAt == proposed.startsAt &&
      current.endsAt == proposed.endsAt &&
      current.status == proposed.status &&
      current.source == proposed.source;
}

bool _isCoolingDown(
  String blockId,
  List<AutomationAuditEntry> entries,
  DateTime now,
  Duration cooldown,
) {
  if (cooldown.inMicroseconds <= 0) {
    return false;
  }
  for (final entry in entries) {
    if (entry.blockId != blockId || !entry.wasApplied) {
      continue;
    }
    final anchor = entry.cooldownAnchor;
    if (anchor.isAfter(now)) {
      // Plan rounds its snapshot time to the minute while audit timestamps keep
      // seconds/microseconds. Treat that small future skew as still cooling down.
      return true;
    }
    if (now.difference(anchor) < cooldown) {
      return true;
    }
  }
  return false;
}
