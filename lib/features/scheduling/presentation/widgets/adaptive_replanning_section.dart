import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_theme.dart';
import '../../../../core/widgets/pulse_components.dart';
import '../../models/replanning_overview.dart';
import '../../models/schedule_block.dart';

class AdaptiveReplanningSection extends StatelessWidget {
  const AdaptiveReplanningSection({
    super.key,
    required this.state,
    required this.onMove,
    required this.onMarkCompleted,
    required this.onMarkMissed,
    required this.onRemove,
    required this.onReviewTask,
  });

  final AsyncValue<ReplanningOverview> state;
  final ValueChanged<ReplanningIssue> onMove;
  final ValueChanged<ScheduleBlock> onMarkCompleted;
  final ValueChanged<ScheduleBlock> onMarkMissed;
  final ValueChanged<ScheduleBlock> onRemove;
  final ValueChanged<String> onReviewTask;

  @override
  Widget build(BuildContext context) {
    final overview = state.asData?.value;
    if (overview == null || !overview.needsAttention) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('adaptive-replanning-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Needs replanning',
          subtitle:
              'JotCue noticed schedule drift. Nothing moves unless you approve it.',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...overview.issues.map(
          (issue) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _ReplanningIssueCard(
              issue: issue,
              onMove: () => onMove(issue),
              onMarkCompleted: issue.block == null
                  ? null
                  : () => onMarkCompleted(issue.block!),
              onMarkMissed: issue.block == null
                  ? null
                  : () => onMarkMissed(issue.block!),
              onRemove: issue.block == null
                  ? null
                  : () => onRemove(issue.block!),
              onReviewTask: issue.taskId == null
                  ? null
                  : () => onReviewTask(issue.taskId!),
            ),
          ),
        ),
        if (!overview.calendarConflictsChecked)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Calendar conflict checks are unavailable until device-calendar access is available. Other schedule checks still run.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ReplanningIssueCard extends StatelessWidget {
  const _ReplanningIssueCard({
    required this.issue,
    required this.onMove,
    required this.onMarkCompleted,
    required this.onMarkMissed,
    required this.onRemove,
    required this.onReviewTask,
  });

  final ReplanningIssue issue;
  final VoidCallback onMove;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onMarkMissed;
  final VoidCallback? onRemove;
  final VoidCallback? onReviewTask;

  @override
  Widget build(BuildContext context) {
    final isUrgent = issue.kind == ReplanningIssueKind.urgentCapacity;
    return AppCard(
      color: isUrgent ? AppColors.butter : AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(issue.kind), size: 21),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      issue.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (issue.block != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${_formatDay(context, issue.block!.startsAt)} · ${_formatClock(context, issue.block!.startsAt)}–${_formatClock(context, issue.block!.endsAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (issue.suggestion != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Suggested: ${_formatDay(context, issue.suggestion!.startsAt)} · ${_formatClock(context, issue.suggestion!.startsAt)}–${_formatClock(context, issue.suggestion!.endsAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _actions(),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    if (issue.kind == ReplanningIssueKind.pastBlockReview) {
      return [
        if (onMarkCompleted != null)
          FilledButton.tonal(
            onPressed: onMarkCompleted,
            child: const Text('Completed'),
          ),
        if (issue.suggestion != null)
          OutlinedButton(onPressed: onMove, child: const Text('Move')),
        if (onMarkMissed != null)
          TextButton(onPressed: onMarkMissed, child: const Text('Missed')),
      ];
    }
    if (issue.kind == ReplanningIssueKind.calendarConflict ||
        issue.kind == ReplanningIssueKind.outsideAvailability) {
      return [
        if (issue.suggestion != null)
          FilledButton.tonal(onPressed: onMove, child: const Text('Move')),
        if (onRemove != null)
          TextButton(onPressed: onRemove, child: const Text('Remove')),
      ];
    }
    return [
      if (issue.block != null && issue.suggestion != null)
        FilledButton.tonal(onPressed: onMove, child: const Text('Move block')),
      if (onReviewTask != null)
        TextButton(onPressed: onReviewTask, child: const Text('Review task')),
    ];
  }
}

IconData _iconFor(ReplanningIssueKind kind) => switch (kind) {
  ReplanningIssueKind.pastBlockReview => Icons.history_rounded,
  ReplanningIssueKind.calendarConflict => Icons.event_busy_rounded,
  ReplanningIssueKind.outsideAvailability => Icons.schedule_rounded,
  ReplanningIssueKind.urgentCapacity => Icons.warning_amber_rounded,
};

String _formatClock(BuildContext context, DateTime value) {
  return TimeOfDay.fromDateTime(value).format(context);
}

String _formatDay(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatShortDate(value);
}
