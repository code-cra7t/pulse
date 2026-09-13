import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/pulse_components.dart';
import '../models/automation_audit_entry.dart';

class AutomationActivitySection extends StatelessWidget {
  const AutomationActivitySection({super.key, required this.state});

  final AsyncValue<List<AutomationAuditEntry>> state;

  @override
  Widget build(BuildContext context) {
    final entries = state.asData?.value ?? const <AutomationAuditEntry>[];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('automation-activity-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Automation activity',
          subtitle:
              '${entries.length} trusted move attempt${entries.length == 1 ? '' : 's'} recorded on this device',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...entries
            .take(3)
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppCard(
                  color: entry.status == AutomationAuditStatus.failed
                      ? AppColors.butter
                      : AppColors.mint,
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
                        entry.status == AutomationAuditStatus.failed &&
                                entry.error != null
                            ? 'Move failed: ${entry.error}'
                            : entry.reason,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Local JotCue block only · ${_formatClock(context, entry.executedAt)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
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
      ],
    );
  }
}

String _statusLabel(AutomationAuditStatus status) => switch (status) {
  AutomationAuditStatus.pending => 'Pending',
  AutomationAuditStatus.succeeded => 'Moved',
  AutomationAuditStatus.failed => 'Failed',
};

String _formatClock(BuildContext context, DateTime value) {
  return TimeOfDay.fromDateTime(value).format(context);
}

String _formatDay(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatShortDate(value);
}
