import 'package:flutter/material.dart';

import '../../../../core/services/app_theme.dart';
import '../../models/scheduling_preferences.dart';

Future<SchedulingPreferences?> showSchedulingPreferencesSheet({
  required BuildContext context,
  required SchedulingPreferences initial,
}) {
  return showModalBottomSheet<SchedulingPreferences>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SchedulingPreferencesSheet(initial: initial),
  );
}

class _SchedulingPreferencesSheet extends StatefulWidget {
  const _SchedulingPreferencesSheet({required this.initial});

  final SchedulingPreferences initial;

  @override
  State<_SchedulingPreferencesSheet> createState() =>
      _SchedulingPreferencesSheetState();
}

class _SchedulingPreferencesSheetState
    extends State<_SchedulingPreferencesSheet> {
  late int _dayStartMinutes;
  late int _dayEndMinutes;
  late Set<int> _weekdays;
  late int _minimumBlockMinutes;
  late int _preferredBlockMinutes;
  late int _breakMinutes;
  late int _maxFocusMinutesPerDay;
  late int _defaultTaskMinutes;
  late bool _protectLunch;
  late int _lunchStartMinutes;
  late int _lunchEndMinutes;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _dayStartMinutes = value.dayStartMinutes;
    _dayEndMinutes = value.dayEndMinutes;
    _weekdays = value.availableWeekdays.toSet();
    _minimumBlockMinutes = value.minimumBlockMinutes;
    _preferredBlockMinutes = value.preferredBlockMinutes;
    _breakMinutes = value.breakMinutes;
    _maxFocusMinutesPerDay = value.maxFocusMinutesPerDay;
    _defaultTaskMinutes = value.defaultTaskMinutes;
    _protectLunch = value.protectLunch;
    _lunchStartMinutes = value.lunchStartMinutes;
    _lunchEndMinutes = value.lunchEndMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planning availability',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'JotCue only proposes work inside these boundaries. Calendar events are subtracted separately.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          _TimeTile(
            label: 'Earliest planning time',
            minutes: _dayStartMinutes,
            onChanged: (value) => setState(() => _dayStartMinutes = value),
          ),
          _TimeTile(
            label: 'Latest planning time',
            minutes: _dayEndMinutes,
            onChanged: (value) => setState(() => _dayEndMinutes = value),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Available days', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children:
                const [
                  (DateTime.monday, 'Mon'),
                  (DateTime.tuesday, 'Tue'),
                  (DateTime.wednesday, 'Wed'),
                  (DateTime.thursday, 'Thu'),
                  (DateTime.friday, 'Fri'),
                  (DateTime.saturday, 'Sat'),
                  (DateTime.sunday, 'Sun'),
                ].map((entry) {
                  final day = entry.$1;
                  return FilterChip(
                    label: Text(entry.$2),
                    selected: _weekdays.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _weekdays.add(day);
                        } else if (_weekdays.length > 1) {
                          _weekdays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          _MinutesDropdown(
            label: 'Minimum useful block',
            value: _minimumBlockMinutes,
            values: const [15, 30, 45, 60, 90, 120, 180, 240],
            onChanged: (value) {
              setState(() {
                _minimumBlockMinutes = value;
                if (_preferredBlockMinutes < value) {
                  _preferredBlockMinutes = value;
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _MinutesDropdown(
            label: 'Preferred focus block',
            value: _preferredBlockMinutes,
            values: const [30, 45, 60, 90, 120, 180, 240, 300, 360],
            onChanged: (value) =>
                setState(() => _preferredBlockMinutes = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MinutesDropdown(
            label: 'Break between suggested blocks',
            value: _breakMinutes,
            values: const [0, 10, 15, 20, 30, 45, 60, 90, 120],
            onChanged: (value) => setState(() => _breakMinutes = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MinutesDropdown(
            label: 'Maximum planned focus per day',
            value: _maxFocusMinutesPerDay,
            values: const [120, 180, 240, 300, 360, 480, 600, 720, 960],
            onChanged: (value) =>
                setState(() => _maxFocusMinutesPerDay = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MinutesDropdown(
            label: 'Default time for unestimated tasks',
            value: _defaultTaskMinutes,
            values: const [15, 30, 45, 60, 90, 120, 180, 240, 360, 480],
            onChanged: (value) => setState(() => _defaultTaskMinutes = value),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Protect a lunch window'),
            subtitle: const Text(
              'JotCue will not propose focused work during this time.',
            ),
            value: _protectLunch,
            onChanged: (value) => setState(() => _protectLunch = value),
          ),
          if (_protectLunch) ...[
            _TimeTile(
              label: 'Lunch starts',
              minutes: _lunchStartMinutes,
              onChanged: (value) => setState(() => _lunchStartMinutes = value),
            ),
            _TimeTile(
              label: 'Lunch ends',
              minutes: _lunchEndMinutes,
              onChanged: (value) => setState(() => _lunchEndMinutes = value),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Save planning availability'),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSave {
    return SchedulingPreferences(
      isConfigured: true,
      dayStartMinutes: _dayStartMinutes,
      dayEndMinutes: _dayEndMinutes,
      availableWeekdays: _weekdays.toList()..sort(),
      minimumBlockMinutes: _minimumBlockMinutes,
      preferredBlockMinutes: _preferredBlockMinutes,
      breakMinutes: _breakMinutes,
      maxFocusMinutesPerDay: _maxFocusMinutesPerDay,
      defaultTaskMinutes: _defaultTaskMinutes,
      protectLunch: _protectLunch,
      lunchStartMinutes: _lunchStartMinutes,
      lunchEndMinutes: _lunchEndMinutes,
    ).isValid;
  }

  void _save() {
    final value = SchedulingPreferences(
      isConfigured: true,
      dayStartMinutes: _dayStartMinutes,
      dayEndMinutes: _dayEndMinutes,
      availableWeekdays: _weekdays.toList()..sort(),
      minimumBlockMinutes: _minimumBlockMinutes,
      preferredBlockMinutes: _preferredBlockMinutes,
      breakMinutes: _breakMinutes,
      maxFocusMinutesPerDay: _maxFocusMinutesPerDay,
      defaultTaskMinutes: _defaultTaskMinutes,
      protectLunch: _protectLunch,
      lunchStartMinutes: _lunchStartMinutes,
      lunchEndMinutes: _lunchEndMinutes,
    );
    Navigator.of(context).pop(value);
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        time.format(context),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: () async {
        final selected = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (selected != null) {
          onChanged(selected.hour * 60 + selected.minute);
        }
      },
    );
  }
}

class _MinutesDropdown extends StatelessWidget {
  const _MinutesDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (minutes) => DropdownMenuItem(
              value: minutes,
              child: Text(_formatMinutes(minutes)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

String _formatMinutes(int minutes) {
  if (minutes == 0) {
    return 'No break';
  }
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}
