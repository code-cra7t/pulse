import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_theme.dart';
import '../../../../core/widgets/pulse_components.dart';
import '../../models/schedule_block.dart';
import '../../models/schedule_proposal.dart';
import '../../models/scheduling_day_state.dart';

typedef ScheduleBlockCalendarCheck = Future<bool> Function(ScheduleBlock block);
typedef ScheduleBlockCalendarAction =
    Future<bool> Function(ScheduleBlock block);

class SuggestedScheduleSection extends StatelessWidget {
  const SuggestedScheduleSection({
    super.key,
    required this.state,
    required this.onConfigure,
    required this.onRequestCalendar,
    required this.onAccept,
    required this.onRemoveBlock,
    required this.calendarWriteSupported,
    required this.onCalendarLinked,
    required this.onAddOrUpdateCalendar,
    required this.onRemoveCalendar,
  });

  final AsyncValue<SchedulingDayState> state;
  final VoidCallback onConfigure;
  final VoidCallback onRequestCalendar;
  final ValueChanged<ScheduleProposal> onAccept;
  final ValueChanged<ScheduleBlock> onRemoveBlock;
  final bool calendarWriteSupported;
  final ScheduleBlockCalendarCheck onCalendarLinked;
  final ScheduleBlockCalendarAction onAddOrUpdateCalendar;
  final ScheduleBlockCalendarAction onRemoveCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('suggested-schedule-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Suggested schedule',
          subtitle: 'A proposal only. JotCue will not change your calendar.',
        ),
        const SizedBox(height: AppSpacing.sm),
        state.when(
          loading: () => const AppCard(
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Checking today’s planning window…')),
              ],
            ),
          ),
          error: (error, _) => AppCard(
            color: AppColors.butter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not prepare today’s schedule',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('$error'),
              ],
            ),
          ),
          data: (value) => _ScheduleStateCard(
            value: value,
            onConfigure: onConfigure,
            onRequestCalendar: onRequestCalendar,
            onAccept: onAccept,
            onRemoveBlock: onRemoveBlock,
            calendarWriteSupported: calendarWriteSupported,
            onCalendarLinked: onCalendarLinked,
            onAddOrUpdateCalendar: onAddOrUpdateCalendar,
            onRemoveCalendar: onRemoveCalendar,
          ),
        ),
      ],
    );
  }
}

class _ScheduleStateCard extends StatelessWidget {
  const _ScheduleStateCard({
    required this.value,
    required this.onConfigure,
    required this.onRequestCalendar,
    required this.onAccept,
    required this.onRemoveBlock,
    required this.calendarWriteSupported,
    required this.onCalendarLinked,
    required this.onAddOrUpdateCalendar,
    required this.onRemoveCalendar,
  });

  final SchedulingDayState value;
  final VoidCallback onConfigure;
  final VoidCallback onRequestCalendar;
  final ValueChanged<ScheduleProposal> onAccept;
  final ValueChanged<ScheduleBlock> onRemoveBlock;
  final bool calendarWriteSupported;
  final ScheduleBlockCalendarCheck onCalendarLinked;
  final ScheduleBlockCalendarAction onAddOrUpdateCalendar;
  final ScheduleBlockCalendarAction onRemoveCalendar;

  @override
  Widget build(BuildContext context) {
    if (!value.isConfigured) {
      return AppCard(
        color: AppColors.lavender,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule_rounded, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tell JotCue when it may plan work',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Set your available days, focus window, break length, and daily limit before JotCue suggests times.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onConfigure,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Set planning availability'),
            ),
          ],
        ),
      );
    }

    if (!value.isEnabledDay) {
      return AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_busy_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No planning window today',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Today is outside the days you allowed JotCue to schedule focused work.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onConfigure,
                    child: const Text('Change availability'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (value.needsCalendarAccess) {
      return AppCard(
        color: AppColors.sky,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Connect your device calendar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'JotCue reads busy times locally so suggestions do not overlap classes, meetings, or appointments. Calendar contents are not uploaded.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onRequestCalendar,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Allow calendar access'),
            ),
          ],
        ),
      );
    }

    final proposal = value.proposal;
    final availability = value.availability;
    if (availability == null) {
      return const AppCard(
        child: Text('No availability information is available for today.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: AppColors.mint,
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _ScheduleMetric(
                label: 'Free now',
                value: _formatDurationMinutes(availability.freeMinutes),
              ),
              _ScheduleMetric(
                label: 'Planned / done',
                value: _formatDurationMinutes(
                  proposal?.acceptedMinutes ??
                      value.acceptedBlocks.fold<int>(
                        0,
                        (sum, block) => sum + block.duration.inMinutes,
                      ),
                ),
              ),
              _ScheduleMetric(
                label: 'Suggested',
                value: _formatDurationMinutes(proposal?.proposedMinutes ?? 0),
              ),
            ],
          ),
        ),
        if (!value.calendarSupported) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Device calendar busy-time reading is unavailable on this platform, so these suggestions use only your JotCue availability settings.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (value.acceptedBlocks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ...value.acceptedBlocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _AcceptedScheduleBlock(
                block: block,
                onRemove: () => onRemoveBlock(block),
                calendarWriteSupported: calendarWriteSupported,
                onCalendarLinked: onCalendarLinked,
                onAddOrUpdateCalendar: onAddOrUpdateCalendar,
                onRemoveCalendar: onRemoveCalendar,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (proposal == null || proposal.proposals.isEmpty)
          AppCard(
            child: Text(
              availability.freeMinutes == 0
                  ? 'There is no usable time left inside today’s planning window.'
                  : 'No flexible open tasks need another suggested block right now.',
            ),
          )
        else ...[
          ...proposal.proposals.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _ScheduleProposalCard(
                proposal: item,
                onAccept: () => onAccept(item),
              ),
            ),
          ),
          if (proposal.assumedEffortCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${proposal.assumedEffortCount} ${proposal.assumedEffortCount == 1 ? 'task uses' : 'tasks use'} your default duration because no effort estimate was set.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (proposal.unscheduledTaskCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${proposal.unscheduledTaskCount} ${proposal.unscheduledTaskCount == 1 ? 'task does' : 'tasks do'} not fit in the remaining focus budget today.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _ScheduleMetric extends StatelessWidget {
  const _ScheduleMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

enum _CalendarBlockAction { upsert, remove }

class _AcceptedScheduleBlock extends StatefulWidget {
  const _AcceptedScheduleBlock({
    required this.block,
    required this.onRemove,
    required this.calendarWriteSupported,
    required this.onCalendarLinked,
    required this.onAddOrUpdateCalendar,
    required this.onRemoveCalendar,
  });

  final ScheduleBlock block;
  final VoidCallback onRemove;
  final bool calendarWriteSupported;
  final ScheduleBlockCalendarCheck onCalendarLinked;
  final ScheduleBlockCalendarAction onAddOrUpdateCalendar;
  final ScheduleBlockCalendarAction onRemoveCalendar;

  @override
  State<_AcceptedScheduleBlock> createState() => _AcceptedScheduleBlockState();
}

class _AcceptedScheduleBlockState extends State<_AcceptedScheduleBlock> {
  late Future<bool> _linked;

  @override
  void initState() {
    super.initState();
    _refreshLink();
  }

  @override
  void didUpdateWidget(covariant _AcceptedScheduleBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.calendarWriteSupported != widget.calendarWriteSupported) {
      _refreshLink();
    }
  }

  void _refreshLink() {
    _linked = widget.calendarWriteSupported
        ? widget.onCalendarLinked(widget.block)
        : Future<bool>.value(false);
  }

  Future<void> _runCalendarAction(_CalendarBlockAction action) async {
    final changed = switch (action) {
      _CalendarBlockAction.upsert => await widget.onAddOrUpdateCalendar(
        widget.block,
      ),
      _CalendarBlockAction.remove => await widget.onRemoveCalendar(
        widget.block,
      ),
    };
    if (!mounted || !changed) return;
    setState(_refreshLink);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.block.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                FutureBuilder<bool>(
                  future: _linked,
                  builder: (context, snapshot) {
                    final suffix = snapshot.data == true
                        ? ' · Calendar linked'
                        : '';
                    return Text(
                      '${_formatClock(context, widget.block.startsAt)}–${_formatClock(context, widget.block.endsAt)} · Accepted on this device$suffix',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.calendarWriteSupported)
            FutureBuilder<bool>(
              future: _linked,
              builder: (context, snapshot) {
                final linked = snapshot.data == true;
                return PopupMenuButton<_CalendarBlockAction>(
                  tooltip: 'Calendar options',
                  icon: Icon(
                    linked
                        ? Icons.event_available_outlined
                        : Icons.event_outlined,
                    size: 20,
                  ),
                  onSelected: _runCalendarAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _CalendarBlockAction.upsert,
                      child: Text(
                        linked ? 'Update calendar entry' : 'Add to calendar',
                      ),
                    ),
                    if (linked)
                      const PopupMenuItem(
                        value: _CalendarBlockAction.remove,
                        child: Text('Remove from calendar'),
                      ),
                  ],
                );
              },
            ),
          IconButton(
            onPressed: widget.onRemove,
            tooltip: 'Remove planned block',
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _ScheduleProposalCard extends StatelessWidget {
  const _ScheduleProposalCard({required this.proposal, required this.onAccept});

  final ScheduleProposal proposal;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatClock(context, proposal.startsAt)}–${_formatClock(context, proposal.endsAt)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proposal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${proposal.reason} · ${_formatDurationMinutes(proposal.minutes)}${proposal.assumedEffort ? ' · assumed duration' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _formatClock(BuildContext context, DateTime value) {
  return TimeOfDay.fromDateTime(value).format(context);
}

String _formatDurationMinutes(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainder}m';
}
