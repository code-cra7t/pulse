import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../models/attention_preferences.dart';

Future<AttentionPreferences?> showAttentionPreferencesSheet({
  required BuildContext context,
  required AttentionPreferences initial,
}) {
  return showModalBottomSheet<AttentionPreferences>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AttentionPreferencesSheet(initial: initial),
  );
}

class _AttentionPreferencesSheet extends StatefulWidget {
  const _AttentionPreferencesSheet({required this.initial});
  final AttentionPreferences initial;

  @override
  State<_AttentionPreferencesSheet> createState() =>
      _AttentionPreferencesSheetState();
}

class _AttentionPreferencesSheetState
    extends State<_AttentionPreferencesSheet> {
  late AttentionPreferences value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Proactive attention',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'JotCue only surfaces useful changes and routines. No engagement nudges.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Proactive attention'),
              subtitle: const Text(
                'Allow JotCue to schedule attention cues on this device.',
              ),
              value: value.enabled,
              onChanged: (enabled) =>
                  setState(() => value = value.copyWith(enabled: enabled)),
            ),
            const Divider(),
            _RoutineTile(
              title: 'Morning Pulse',
              enabled: value.morningPulseEnabled,
              minutes: value.morningMinutes,
              onEnabled: (enabled) => setState(
                () => value = value.copyWith(morningPulseEnabled: enabled),
              ),
              onTime: () => _pickTime(
                value.morningMinutes,
                (minutes) => value = value.copyWith(morningMinutes: minutes),
              ),
            ),
            _RoutineTile(
              title: 'Daily Closing',
              enabled: value.dailyClosingEnabled,
              minutes: value.closingMinutes,
              onEnabled: (enabled) => setState(
                () => value = value.copyWith(dailyClosingEnabled: enabled),
              ),
              onTime: () => _pickTime(
                value.closingMinutes,
                (minutes) => value = value.copyWith(closingMinutes: minutes),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deadline resurfacing'),
              subtitle: const Text(
                'Surface overdue and imminent work when it becomes relevant.',
              ),
              value: value.deadlineAlertsEnabled,
              onChanged: (enabled) => setState(
                () => value = value.copyWith(deadlineAlertsEnabled: enabled),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Schedule attention'),
              subtitle: const Text(
                'Notify when conflicts, capacity, or past blocks need review.',
              ),
              value: value.scheduleAlertsEnabled,
              onChanged: (enabled) => setState(
                () => value = value.copyWith(scheduleAlertsEnabled: enabled),
              ),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiet hours'),
              subtitle: Text(
                value.quietHoursEnabled
                    ? '${_format(value.quietStartMinutes)} – ${_format(value.quietEndMinutes)}'
                    : 'Off',
              ),
              value: value.quietHoursEnabled,
              onChanged: (enabled) => setState(
                () => value = value.copyWith(quietHoursEnabled: enabled),
              ),
            ),
            if (value.quietHoursEnabled)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(
                        value.quietStartMinutes,
                        (minutes) =>
                            value = value.copyWith(quietStartMinutes: minutes),
                      ),
                      child: Text('Starts ${_format(value.quietStartMinutes)}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(
                        value.quietEndMinutes,
                        (minutes) =>
                            value = value.copyWith(quietEndMinutes: minutes),
                      ),
                      child: Text('Ends ${_format(value.quietEndMinutes)}'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: value.isValid
                  ? () => Navigator.of(context).pop(value)
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(
    int minutes,
    AttentionPreferences Function(int) update,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    setState(() => value = update(picked.hour * 60 + picked.minute));
  }

  String _format(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.title,
    required this.enabled,
    required this.minutes,
    required this.onEnabled,
    required this.onTime,
  });
  final String title;
  final bool enabled;
  final int minutes;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    final label = TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    ).format(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(enabled ? label : 'Off'),
      value: enabled,
      onChanged: onEnabled,
      secondary: IconButton(
        onPressed: enabled ? onTime : null,
        icon: const Icon(Icons.schedule_outlined),
        tooltip: 'Change time',
      ),
    );
  }
}
