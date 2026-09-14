import '../../reasoning/models/contextual_reasoning.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../models/daily_pulse_loop.dart';
import '../models/proactive_pulse.dart';

/// Turns deterministic contextual reasoning into concise proactive copy.
///
/// This layer is presentation-only. It never mutates planning state, creates
/// new graph facts, calls Hybrid AI, or invents availability. Every time or
/// recovery suggestion shown here already exists in the reasoning/replanning
/// read models.
class ProactivePulseEngine {
  const ProactivePulseEngine();

  ProactivePulseSnapshot build({
    required DateTime now,
    required ContextualReasoningResult reasoning,
    required DailyPulseLoop loop,
    ReplanningOverview? replanning,
  }) {
    final primary = reasoning.primary;
    final blockedMessage = _blockedMessage(
      reasoning.blockedTaskCount,
      hasPrimary: primary != null,
    );
    final timingMessage = primary?.executionWindow == null
        ? null
        : _windowMessage(primary!.executionWindow!, now);
    final recoveryMessage = _recoveryMessage(
      now: now,
      reasoning: reasoning,
      loop: loop,
      replanning: replanning,
    );

    final focusMessage = primary == null
        ? reasoning.blockedTaskCount > 0
              ? 'Nothing is ready yet; blocked work can stay out of focus.'
              : 'Nothing is asking for your attention right now.'
        : '${primary.task.title} — ${_reasonSummary(primary)}.';

    final morningParts = <String>[];
    if (primary != null) {
      morningParts.add('Start with ${primary.task.title}.');
      morningParts.add('${_reasonSummary(primary)}.');
    } else if (reasoning.blockedTaskCount > 0) {
      morningParts.add('Nothing is ready to start yet.');
    } else {
      morningParts.add('Your current plan has no strong next action.');
    }
    if (timingMessage != null) {
      morningParts.add(timingMessage);
    }
    if (blockedMessage != null) {
      morningParts.add(blockedMessage);
    }

    final closingMessage = _closingMessage(
      reasoning: reasoning,
      loop: loop,
      recoveryMessage: recoveryMessage,
    );

    final attentionParts = <String>[];
    if (recoveryMessage != null) {
      attentionParts.add(recoveryMessage);
    } else {
      attentionParts.add(focusMessage);
      if (timingMessage != null) {
        attentionParts.add(timingMessage);
      }
    }
    if (blockedMessage != null) {
      attentionParts.add(blockedMessage);
    }

    return ProactivePulseSnapshot(
      generatedAt: now,
      morningMessage: morningParts.join(' '),
      focusMessage: focusMessage,
      closingMessage: closingMessage,
      attentionMessage: attentionParts.join(' '),
      blockedMessage: blockedMessage,
      timingMessage: timingMessage,
      recoveryMessage: recoveryMessage,
    );
  }

  String _reasonSummary(ContextualTaskRecommendation recommendation) {
    final reasons = recommendation.reasons
        .where((reason) => reason.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (reasons.isEmpty) {
      return 'Ready to work on';
    }
    return reasons.join(' · ');
  }

  String? _blockedMessage(int count, {required bool hasPrimary}) {
    if (count <= 0) {
      return null;
    }
    final qualifier = hasPrimary ? 'other ' : '';
    return count == 1
        ? '1 ${qualifier}open task is blocked and can stay out of focus until its blocker clears.'
        : '$count ${qualifier}open tasks are blocked and can stay out of focus until their blockers clear.';
  }

  String _windowMessage(ContextualExecutionWindow window, DateTime now) {
    final range = _range(window.startsAt, window.endsAt, now);
    return switch (window.kind) {
      ContextualExecutionWindowKind.activeScheduleBlock =>
        'Use the current block until ${_clock(window.endsAt)}.',
      ContextualExecutionWindowKind.acceptedScheduleBlock =>
        'Best confirmed window: $range.',
      ContextualExecutionWindowKind.scheduleProposal =>
        'Current schedule proposal: $range.',
      ContextualExecutionWindowKind.replanningSuggestion =>
        'Recovery window: $range.',
      ContextualExecutionWindowKind.freeAvailability =>
        'Earliest fitting free window: $range.',
    };
  }

  String? _recoveryMessage({
    required DateTime now,
    required ContextualReasoningResult reasoning,
    required DailyPulseLoop loop,
    required ReplanningOverview? replanning,
  }) {
    final primaryId = reasoning.primary?.task.id;
    ReplanningIssue? selected;
    final recoverable = replanning?.issues
        .where((issue) {
          final suggestion = issue.suggestion;
          return suggestion != null && suggestion.endsAt.isAfter(now);
        })
        .toList(growable: false);

    if (recoverable != null && recoverable.isNotEmpty) {
      if (primaryId != null) {
        for (final issue in recoverable) {
          if (issue.taskId == primaryId) {
            selected = issue;
            break;
          }
        }
      }
      selected ??= recoverable.first;
    }

    if (selected != null) {
      final suggestion = selected.suggestion!;
      final label = _issueLabel(selected, reasoning);
      final range = _range(suggestion.startsAt, suggestion.endsAt, now);
      return selected.kind == ReplanningIssueKind.pastBlockReview
          ? '$label slipped. Recover it $range.'
          : '$label needs a new slot. Best recovery window: $range.';
    }

    if (loop.unresolvedPastBlocks.isNotEmpty) {
      final block = loop.unresolvedPastBlocks.first;
      return '${block.title} ended without a decision. Mark it completed or missed, or move it from Plan if it still belongs later.';
    }

    return null;
  }

  String _issueLabel(
    ReplanningIssue issue,
    ContextualReasoningResult reasoning,
  ) {
    final blockTitle = issue.block?.title.trim();
    if (blockTitle != null && blockTitle.isNotEmpty) {
      return blockTitle;
    }
    final taskId = issue.taskId;
    if (taskId != null) {
      final primary = reasoning.primary;
      if (primary?.task.id == taskId) {
        return primary!.task.title;
      }
      final alternative = reasoning.alternative;
      if (alternative?.task.id == taskId) {
        return alternative!.task.title;
      }
    }
    final title = issue.title.trim();
    return title.isEmpty ? 'Planned work' : title;
  }

  String _closingMessage({
    required ContextualReasoningResult reasoning,
    required DailyPulseLoop loop,
    required String? recoveryMessage,
  }) {
    if (recoveryMessage != null) {
      return recoveryMessage;
    }

    if (loop.unresolvedCount > 0) {
      return loop.unresolvedCount == 1
          ? '1 past block still needs a decision before tomorrow inherits it.'
          : '${loop.unresolvedCount} past blocks still need decisions before tomorrow inherits them.';
    }

    if (loop.upcomingCount > 0) {
      final primary = reasoning.primary;
      if (primary != null) {
        return '${loop.upcomingCount} ${loop.upcomingCount == 1 ? 'planned block remains' : 'planned blocks remain'} today. ${primary.task.title} is still the strongest current signal.';
      }
      return '${loop.upcomingCount} ${loop.upcomingCount == 1 ? 'planned block remains' : 'planned blocks remain'} today.';
    }

    if (loop.completedCount > 0 && loop.missedCount == 0) {
      final primary = reasoning.primary;
      if (primary == null) {
        return 'Everything planned in JotCue today is closed out.';
      }
      return 'Everything planned in JotCue today is closed out. ${primary.task.title} is the strongest open signal for the next planning pass.';
    }

    if (loop.todayBlocks.isEmpty) {
      final primary = reasoning.primary;
      if (primary == null) {
        return 'Nothing was planned in JotCue today. Review open work in Plan before calling it a day.';
      }
      return 'Nothing was planned in JotCue today. ${primary.task.title} is the strongest open signal for the next planning pass.';
    }

    return 'Today is accounted for. Review tomorrow in Plan if anything needs a new home.';
  }

  String _range(DateTime start, DateTime end, DateTime now) {
    if (_sameDay(start, now)) {
      return '${_clock(start)}–${_clock(end)} today';
    }
    return '${_month(start.month)} ${start.day}, ${_clock(start)}–${_clock(end)}';
  }

  String _clock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
