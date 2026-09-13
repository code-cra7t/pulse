import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/pulse_components.dart';
import '../models/automation_audit_entry.dart';
import '../models/automation_safety_preferences.dart';

class AutomationActivitySection extends StatelessWidget {
  const AutomationActivitySection({
    super.key,
    required this.state,
    required this.safety,
    required this.trustedEnabled,
    required this.onTogglePaused,
    required this.onManageSafety,
    required this.onUndo,
    required this.onClearOlderActivity,
  });

  final AsyncValue<List<AutomationAuditEntry>> state;
  final AutomationSafetyPreferences safety;
  final bool trustedEnabled;
  final Future<void> Function(bool paused) onTogglePaused;
  final VoidCallback onManageSafety;
  final Future<void> Function(AutomationAuditEntry entry) onUndo;
  final Future<void> Function() onClearOlderActivity;

  @override
  Widget build(BuildContext context) {
    final entries = state.asData?.value ?? const <AutomationAuditEntry>[];
    if (entries.isEmpty && !trustedEnabled) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('automation-activity-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Automation activity',
          subtitle: trustedEnabled
              ? safety.paused
                    ? 'Trusted schedule moves are paused on this device.'
                    : 'Trusted moves stay local, guarded, and reversible when safe.'
              : '${entries.length} trusted move attempt${entries.length == 1 ? '' : 's'} recorded on this device',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (trustedEnabled) ...[
          AppCard(
            color: safety.paused ? AppColors.butter : AppColors.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      safety.paused
                          ? Icons.pause_circle_outline_rounded
                          : Icons.shield_outlined,
                    ),
                    Text(
                      safety.paused
                          ? 'Trusted moves paused'
                          : 'Trusted safety is active',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  safety.exclusionCount == 0
                      ? '30-minute bounce protection is active. No task or project exclusions are set.'
                      : '${safety.exclusionCount} task/project exclusion${safety.exclusionCount == 1 ? '' : 's'} · 30-minute bounce protection active.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('trusted-automation-pause-action'),
                      onPressed: () async {
                        await onTogglePaused(!safety.paused);
                      },
                      icon: Icon(
                        safety.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(safety.paused ? 'Resume' : 'Pause'),
                    ),
                    TextButton.icon(
                      onPressed: onManageSafety,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Safety controls'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        ],
        ...entries
            .take(3)
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppCard(
                  color: _entryColor(entry.status),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            _statusLabel(entry.status),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDay(context, entry.fromStartsAt)} ${_formatClock(context, entry.fromStartsAt)} → '
                        '${_formatDay(context, entry.toStartsAt)} ${_formatClock(context, entry.toStartsAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _description(entry),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Local JotCue block only · ${_formatClock(context, entry.executedAt)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (entry.status == AutomationAuditStatus.succeeded) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _UndoButton(entry: entry, onUndo: onUndo),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        if (entries.length > 3)
          Text(
            '+ ${entries.length - 3} older trusted attempts kept locally',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            key: const ValueKey('clear-older-automation-activity'),
            onPressed: () async {
              await onClearOlderActivity();
            },
            icon: const Icon(Icons.history_rounded),
            label: const Text('Clear older activity'),
          ),
        ],
      ],
    );
  }
}

class _UndoButton extends StatefulWidget {
  const _UndoButton({required this.entry, required this.onUndo});

  final AutomationAuditEntry entry;
  final Future<void> Function(AutomationAuditEntry entry) onUndo;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: ValueKey('undo-trusted-${widget.entry.id}'),
      onPressed: _working
          ? null
          : () async {
              setState(() => _working = true);
              try {
                await widget.onUndo(widget.entry);
              } finally {
                if (mounted) {
                  setState(() => _working = false);
                }
              }
            },
      icon: _working
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.undo_rounded),
      label: const Text('Undo move'),
    );
  }
}

Color _entryColor(AutomationAuditStatus status) => switch (status) {
  AutomationAuditStatus.failed => AppColors.butter,
  AutomationAuditStatus.undone => AppColors.sky,
  AutomationAuditStatus.pending ||
  AutomationAuditStatus.undoPending => AppColors.lavender,
  AutomationAuditStatus.succeeded => AppColors.mint,
};

String _statusLabel(AutomationAuditStatus status) => switch (status) {
  AutomationAuditStatus.pending => 'Pending',
  AutomationAuditStatus.succeeded => 'Moved',
  AutomationAuditStatus.failed => 'Failed',
  AutomationAuditStatus.undoPending => 'Undo pending',
  AutomationAuditStatus.undone => 'Undone',
};

String _description(AutomationAuditEntry entry) {
  if (entry.status == AutomationAuditStatus.failed && entry.error != null) {
    return 'Move failed: ${entry.error}';
  }
  if (entry.status == AutomationAuditStatus.undoPending) {
    return 'Undo started. JotCue is restoring the original local slot.';
  }
  if (entry.status == AutomationAuditStatus.undone) {
    return 'Undo completed. The block was restored to its original slot.';
  }
  if (entry.undoError != null) {
    return '${entry.reason}\nLast undo attempt failed: ${entry.undoError}';
  }
  return entry.reason;
}

String _formatClock(BuildContext context, DateTime value) {
  return TimeOfDay.fromDateTime(value).format(context);
}

String _formatDay(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatShortDate(value);
}
