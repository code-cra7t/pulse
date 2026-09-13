import '../../../core/models/priority_level.dart';
import '../../automation/data/automation_policy.dart';
import '../../automation/models/automation_preferences.dart';
import '../../scheduling/data/schedule_blocks_repository.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task_metadata_update.dart';
import '../models/ask_jotcue.dart';

typedef SetTaskCompletion =
    Future<void> Function({
      required String userId,
      required String noteId,
      required String taskId,
      required bool isCompleted,
    });

typedef UpdateTaskMetadata =
    Future<void> Function({
      required String userId,
      required String noteId,
      required String taskId,
      required TaskMetadataUpdate update,
    });

typedef CalendarLinkCheck = Future<bool> Function(String blockId);

typedef ScheduleMoveAvailabilityCheck =
    Future<bool> Function({
      required String blockId,
      required DateTime startsAt,
      required DateTime endsAt,
    });

class AskJotCueActionExecutor {
  const AskJotCueActionExecutor({
    required AutomationPolicy policy,
    required SetTaskCompletion setTaskCompletion,
    required UpdateTaskMetadata updateTaskMetadata,
    required ScheduleBlocksRepository scheduleBlocks,
    required CalendarLinkCheck isCalendarLinked,
    required ScheduleMoveAvailabilityCheck isScheduleMoveAvailable,
  }) : _policy = policy,
       _setTaskCompletion = setTaskCompletion,
       _updateTaskMetadata = updateTaskMetadata,
       _scheduleBlocks = scheduleBlocks,
       _isCalendarLinked = isCalendarLinked,
       _isScheduleMoveAvailable = isScheduleMoveAvailable;

  final AutomationPolicy _policy;
  final SetTaskCompletion _setTaskCompletion;
  final UpdateTaskMetadata _updateTaskMetadata;
  final ScheduleBlocksRepository _scheduleBlocks;
  final CalendarLinkCheck _isCalendarLinked;
  final ScheduleMoveAvailabilityCheck _isScheduleMoveAvailable;

  AutomationDecision decisionFor({
    required AutomationPreferences preferences,
    required AskJotCueActionProposal proposal,
  }) {
    return _policy.evaluate(
      preferences: preferences,
      action: _policyAction(proposal.kind),
    );
  }

  Future<String> execute({
    required AutomationPreferences preferences,
    required AskJotCueActionProposal proposal,
    required DateTime now,
    required bool approved,
  }) async {
    final decision = decisionFor(preferences: preferences, proposal: proposal);
    if (decision == AutomationDecision.observeOnly) {
      throw StateError(
        'Assistant permissions are set to Observe, so JotCue will not prepare changes.',
      );
    }
    if (decision == AutomationDecision.suggestOnly) {
      throw StateError(
        'Assistant permissions are set to Suggest, so this stays a suggestion.',
      );
    }
    if (!approved) {
      throw StateError('This action still needs your confirmation.');
    }

    switch (proposal.kind) {
      case AskJotCueActionKind.taskCompletion:
        return _setCompletion(proposal);
      case AskJotCueActionKind.taskPriority:
        return _setPriority(proposal);
      case AskJotCueActionKind.scheduleMove:
        return _moveSchedule(proposal, now);
    }
  }

  Future<String> _setCompletion(AskJotCueActionProposal proposal) async {
    final noteId = proposal.sourceNoteId;
    final target = proposal.targetCompletion;
    if (noteId == null || noteId.isEmpty || target == null) {
      throw StateError('The task completion preview is incomplete.');
    }
    await _setTaskCompletion(
      userId: proposal.userId,
      noteId: noteId,
      taskId: proposal.taskId,
      isCompleted: target,
    );
    return target
        ? 'Marked "${proposal.taskTitle}" complete.'
        : 'Reopened "${proposal.taskTitle}".';
  }

  Future<String> _setPriority(AskJotCueActionProposal proposal) async {
    final noteId = proposal.sourceNoteId;
    final priority = proposal.targetPriority;
    if (noteId == null || noteId.isEmpty || priority == null) {
      throw StateError('The priority preview is incomplete.');
    }
    await _updateTaskMetadata(
      userId: proposal.userId,
      noteId: noteId,
      taskId: proposal.taskId,
      update: TaskMetadataUpdate(priority: priority),
    );
    return 'Set "${proposal.taskTitle}" to ${_priorityLabel(priority)} priority.';
  }

  Future<String> _moveSchedule(
    AskJotCueActionProposal proposal,
    DateTime now,
  ) async {
    final blockId = proposal.blockId;
    final fromStart = proposal.fromStartsAt;
    final fromEnd = proposal.fromEndsAt;
    final toStart = proposal.toStartsAt;
    final toEnd = proposal.toEndsAt;
    if (blockId == null ||
        fromStart == null ||
        fromEnd == null ||
        toStart == null ||
        toEnd == null) {
      throw StateError('The schedule-move preview is incomplete.');
    }
    if (!toStart.isAfter(now) || !toEnd.isAfter(toStart)) {
      throw StateError('Ask JotCue can only move a block to a future time.');
    }

    final blocks = await _scheduleBlocks.readBlocks(proposal.userId);
    ScheduleBlock? current;
    for (final block in blocks) {
      if (block.id == blockId) {
        current = block;
        break;
      }
    }
    if (current == null ||
        current.taskId != proposal.taskId ||
        current.status != ScheduleBlockStatus.scheduled ||
        current.startsAt != fromStart ||
        current.endsAt != fromEnd) {
      throw StateError(
        'That planned block changed after the preview. Ask again before applying the move.',
      );
    }

    bool linked;
    try {
      linked = await _isCalendarLinked(blockId);
    } catch (_) {
      throw StateError(
        'JotCue could not verify the calendar link, so the move was not applied.',
      );
    }
    if (linked) {
      throw StateError(
        'This block has a linked calendar copy. Move it from Plan so JotCue can handle the calendar update separately.',
      );
    }

    bool available;
    try {
      available = await _isScheduleMoveAvailable(
        blockId: blockId,
        startsAt: toStart,
        endsAt: toEnd,
      );
    } catch (_) {
      throw StateError(
        'JotCue could not verify availability for that time, so the move was not applied.',
      );
    }
    if (!available) {
      throw StateError(
        'That time is no longer available in your current planning window.',
      );
    }

    await _scheduleBlocks.rescheduleBlock(
      block: current,
      startsAt: toStart,
      endsAt: toEnd,
    );
    return 'Moved "${proposal.taskTitle}" to ${_formatDateTime(toStart)}.';
  }
}

AutomationActionKind _policyAction(AskJotCueActionKind kind) {
  return switch (kind) {
    AskJotCueActionKind.taskCompletion =>
      AutomationActionKind.workReviewDecision,
    AskJotCueActionKind.taskPriority => AutomationActionKind.taskPlanningUpdate,
    AskJotCueActionKind.scheduleMove => AutomationActionKind.localScheduleMove,
  };
}

String _priorityLabel(PriorityLevel priority) {
  return switch (priority) {
    PriorityLevel.none => 'no',
    PriorityLevel.low => 'low',
    PriorityLevel.medium => 'medium',
    PriorityLevel.high => 'high',
    PriorityLevel.critical => 'critical',
  };
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day at $hour:$minute';
}
