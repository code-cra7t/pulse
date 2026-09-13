import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_theme.dart';
import '../../../../core/widgets/pulse_components.dart';
import '../../models/schedule_block_sync_conflict.dart';

class ScheduleSyncConflictsSection extends StatelessWidget {
  const ScheduleSyncConflictsSection({
    super.key,
    required this.state,
    required this.onDismiss,
  });

  final AsyncValue<List<ScheduleBlockSyncConflict>> state;
  final Future<void> Function(ScheduleBlockSyncConflict conflict) onDismiss;

  @override
  Widget build(BuildContext context) {
    final conflicts =
        state.asData?.value ?? const <ScheduleBlockSyncConflict>[];
    if (conflicts.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('schedule-sync-conflicts-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Schedule sync review',
          subtitle:
              '${conflicts.length} cross-device change${conflicts.length == 1 ? '' : 's'} need a quick review.',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...conflicts
            .take(3)
            .map(
              (conflict) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppCard(
                  color: AppColors.butter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.sync_problem_rounded, size: 18),
                          Text(
                            conflict.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _message(conflict),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (conflict.localBlock != null ||
                          conflict.remoteBlock != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _times(context, conflict),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'The synced JotCue version is now canonical. If this block has a device-calendar copy, review its Calendar options before relying on that copy.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        key: ValueKey('dismiss-schedule-sync-${conflict.id}'),
                        onPressed: () async => onDismiss(conflict),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Reviewed'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        if (conflicts.length > 3)
          Text(
            '+ ${conflicts.length - 3} older sync review${conflicts.length - 3 == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

String _message(ScheduleBlockSyncConflict conflict) => switch (conflict.kind) {
  ScheduleBlockSyncConflictKind.remoteChanged =>
    'Another device changed this planned block while this device had an older view. JotCue kept the newer synced version instead of overwriting it.',
  ScheduleBlockSyncConflictKind.remoteDeleted =>
    'Another device removed this planned block before this device could sync its edit. JotCue kept the synced deletion.',
  ScheduleBlockSyncConflictKind.createCollision =>
    'A block with the same identity already existed in sync. JotCue kept the synced version and did not overwrite it.',
  ScheduleBlockSyncConflictKind.remoteOverlap =>
    'Two synced JotCue blocks now overlap. Both remain visible so you can explicitly move or remove the one you do not want.',
};

String _times(BuildContext context, ScheduleBlockSyncConflict conflict) {
  final local = conflict.localBlock;
  final remote = conflict.remoteBlock;
  if (conflict.kind == ScheduleBlockSyncConflictKind.remoteOverlap &&
      local != null &&
      remote != null) {
    return 'Overlap: ${_dateTime(context, local.startsAt)} and ${_dateTime(context, remote.startsAt)}';
  }
  if (local != null && remote != null) {
    return 'This device: ${_dateTime(context, local.startsAt)}  →  Synced: ${_dateTime(context, remote.startsAt)}';
  }
  if (remote != null) return 'Synced: ${_dateTime(context, remote.startsAt)}';
  if (local != null) {
    return 'This device had: ${_dateTime(context, local.startsAt)}';
  }
  return '';
}

String _dateTime(BuildContext context, DateTime value) {
  final time = TimeOfDay.fromDateTime(value).format(context);
  return '${value.day}/${value.month}/${value.year} $time';
}
