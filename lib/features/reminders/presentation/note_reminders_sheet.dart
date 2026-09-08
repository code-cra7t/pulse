import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../notes/models/note.dart';
import '../../notes/presentation/widgets/note_ui.dart';
import '../models/reminder.dart';
import '../models/reminder_text.dart';
import '../models/repeat_type.dart';
import '../providers/reminders_providers.dart';

class NoteRemindersSheet extends ConsumerStatefulWidget {
  const NoteRemindersSheet({
    super.key,
    required this.note,
    this.initialRepeat = RepeatType.none,
    this.initialIntervalMinutes = 60,
  });

  final Note note;
  final RepeatType initialRepeat;
  final int initialIntervalMinutes;

  @override
  ConsumerState<NoteRemindersSheet> createState() => _NoteRemindersSheetState();
}

class _NoteRemindersSheetState extends ConsumerState<NoteRemindersSheet> {
  DateTime? _selectedDateTime;
  late RepeatType _repeat;
  late int _repeatIntervalMinutes;
  late final TextEditingController _titleController;
  bool _addToCalendar = false;
  bool _alsoSetPhoneAlarm = false;
  bool _isSaving = false;
  bool _isTestingNotification = false;

  @override
  void initState() {
    super.initState();
    _repeat = widget.initialRepeat;
    _repeatIntervalMinutes = widget.initialIntervalMinutes;
    if (_repeat == RepeatType.interval) {
      _selectedDateTime = DateTime.now().add(
        Duration(minutes: _repeatIntervalMinutes),
      );
    }
    _titleController = TextEditingController(
      text: reminderTitleFor(
        noteTitle: widget.note.title,
        noteContent: widget.note.content,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(
      noteRemindersStreamProvider(widget.note.id),
    );
    final reminders = (remindersAsync.asData?.value ?? const <Reminder>[])
        .where((reminder) => !reminder.isCompleted)
        .toList();
    final calendar = ref.watch(calendarEventServiceProvider);
    final alarm = ref.watch(alarmHandoffServiceProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Reminders',
                subtitle: 'A little nudge, right when you need it.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: Color(widget.note.color),
                child: Text(
                  _notePreview(widget.note),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textFor(Color(widget.note.color)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Reminder title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<RepeatType>(
                initialValue: _repeat,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  prefixIcon: Icon(Icons.repeat_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: RepeatType.none, child: Text('Once')),
                  DropdownMenuItem(
                    value: RepeatType.daily,
                    child: Text('Every day'),
                  ),
                  DropdownMenuItem(
                    value: RepeatType.weekly,
                    child: Text('Every week'),
                  ),
                  DropdownMenuItem(
                    value: RepeatType.interval,
                    child: Text('Custom interval'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _repeat = value;
                      if (value == RepeatType.interval &&
                          _selectedDateTime == null) {
                        _selectedDateTime = DateTime.now().add(
                          Duration(minutes: _repeatIntervalMinutes),
                        );
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_repeat == RepeatType.interval)
                AppCard(
                  color: AppColors.butter,
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: AppColors.textFor(AppColors.butter),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Every ${_intervalLabel(_repeatIntervalMinutes)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textFor(AppColors.butter),
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _chooseInterval,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textFor(AppColors.butter),
                        ),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  _selectedDateTime == null
                      ? 'Choose first date and time'
                      : 'First alert ${_formatDateTime(_selectedDateTime!)}',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _addToCalendar,
                onChanged: (value) {
                  setState(() => _addToCalendar = value ?? false);
                },
                title: const Text('Also add to device calendar'),
                subtitle: Text(
                  calendar.supportsManagedEvents
                      ? 'This entry stays linked to the reminder.'
                      : 'Your calendar app manages this export separately.',
                ),
                secondary: const Icon(Icons.calendar_month_outlined),
              ),
              if (alarm.isSupported)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _alsoSetPhoneAlarm,
                  onChanged: (value) {
                    setState(() => _alsoSetPhoneAlarm = value ?? false);
                  },
                  title: const Text('Also set phone alarm'),
                  subtitle: const Text(
                    'Opens Clock so you can review and confirm it.',
                  ),
                  secondary: const Icon(Icons.alarm_add_outlined),
                ),
              Text(
                'JotCue notifications, Clock alarms, and calendar entries are separate.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: _isSaving ? null : _createReminder,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add reminder'),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isTestingNotification
                            ? null
                            : _showImmediateTestNotification,
                        child: const Text('Test now'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isTestingNotification
                            ? null
                            : _scheduleTestNotification,
                        child: const Text('Test in 60s'),
                      ),
                    ),
                  ],
                ),
              ],
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                TextButton.icon(
                  onPressed: _showAlertSettings,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Sound and vibration settings'),
                ),
              if (remindersAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (remindersAsync.hasError)
                EmptyState(
                  title: 'Reminders unavailable',
                  message: '${remindersAsync.error}',
                  icon: Icons.cloud_off_outlined,
                )
              else if (reminders.isEmpty)
                const EmptyState(
                  title: 'No reminders yet',
                  message: 'Choose a date and time to add the first one.',
                  icon: Icons.notifications_none_rounded,
                )
              else
                Column(
                  children: reminders
                      .map(
                        (reminder) => _ReminderTile(
                          reminder: reminder,
                          onToggleComplete: (value) {
                            _toggleReminder(reminder, value ?? false);
                          },
                          onEdit: () => _editReminder(reminder),
                          onStopRepeating: reminder.repeat == RepeatType.none
                              ? null
                              : () => _stopRepeating(reminder),
                          onDelete: () => _deleteReminder(reminder),
                          onAddToCalendar: _isSaving
                              ? null
                              : () => _exportReminder(reminder),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _createReminder() async {
    final selectedDateTime = _selectedDateTime;
    if (selectedDateTime == null) {
      _showMessage('Choose a reminder time first.');
      return;
    }

    if (!selectedDateTime.isAfter(DateTime.now())) {
      _showMessage('Choose a future time.');
      return;
    }
    if (_alsoSetPhoneAlarm &&
        (_repeat != RepeatType.none ||
            !ref
                .read(alarmHandoffServiceProvider)
                .canRepresentDate(selectedDateTime))) {
      _showMessage(
        'Phone Clock can set the next occurrence of a time. Turn off the phone alarm option for future dates or repeating reminders.',
      );
      return;
    }

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      _showMessage('You need to be signed in.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final reminder = await ref
          .read(remindersServiceProvider)
          .createReminder(
            userId: user.uid,
            noteId: widget.note.id,
            title: _titleController.text,
            notePreview: _notePreview(widget.note),
            scheduledAt: selectedDateTime,
            repeat: _repeat,
            repeatIntervalMinutes: _repeat == RepeatType.interval
                ? _repeatIntervalMinutes
                : null,
            notificationId: _notificationId(),
          );

      String? followupWarning;
      if (_addToCalendar) {
        try {
          await ref
              .read(remindersServiceProvider)
              .addReminderToCalendar(reminder);
        } catch (error) {
          followupWarning = 'Calendar export failed: $error';
        }
      }
      if (_alsoSetPhoneAlarm) {
        try {
          await ref
              .read(alarmHandoffServiceProvider)
              .openAlarm(scheduledAt: selectedDateTime, label: reminder.title);
        } catch (error) {
          followupWarning = followupWarning == null
              ? 'Clock could not open: $error'
              : '$followupWarning Clock could not open: $error';
        }
      }

      if (mounted) {
        setState(() {
          _selectedDateTime = null;
        });
        _showMessage(
          followupWarning != null
              ? 'Reminder saved. $followupWarning'
              : _repeat == RepeatType.interval
              ? 'Repeating reminder added${_alsoSetPhoneAlarm ? '; confirm its Clock alarm.' : '.'}'
              : 'Reminder added${_alsoSetPhoneAlarm ? '; confirm its Clock alarm.' : '.'}',
        );
      }
    } catch (error) {
      _showMessage('Could not create reminder: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showImmediateTestNotification() async {
    await _runNotificationTest(
      action: () => ref
          .read(localNotificationsServiceProvider)
          .showImmediateTestNotification(),
      successMessage: 'Test notification sent.',
    );
  }

  Future<void> _exportReminder(Reminder reminder) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(remindersServiceProvider).addReminderToCalendar(reminder);
      _showMessage(
        ref.read(calendarEventServiceProvider).supportsManagedEvents
            ? 'Calendar entry linked.'
            : 'Review the entry in your calendar app.',
      );
    } catch (error) {
      _showMessage('Could not link calendar: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAlertSettings() async {
    try {
      final service = ref.read(localNotificationsServiceProvider);
      final status = await service.getAlertStatus();
      if (!mounted) return;
      String enabled(bool? value) => value == null
          ? 'Not available'
          : value
          ? 'On'
          : 'Off';
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reminder alerts'),
          content: Text(
            'Notifications: ${enabled(status.notificationsAllowed)}\n'
            'Precise timing access: ${enabled(status.exactAlarmsAllowed)}\n'
            'Sound: ${enabled(status.soundEnabled)}\n'
            'Vibration: ${enabled(status.vibrationEnabled)}\n\n'
            'Choose your tone and vibration in phone settings. Volume, Do Not Disturb and battery settings can affect alerts.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Phone settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) await service.openAlertSettings();
    } catch (error) {
      _showMessage('Could not read alert settings: $error');
    }
  }

  Future<void> _scheduleTestNotification() async {
    await _runNotificationTest(
      action: () => ref
          .read(localNotificationsServiceProvider)
          .scheduleTestNotificationIn60Seconds(),
      successMessage: 'Test notification scheduled for 60 seconds.',
    );
  }

  Future<void> _runNotificationTest({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() {
      _isTestingNotification = true;
    });
    try {
      await action();
      if (mounted) {
        _showMessage(successMessage);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Notification test failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingNotification = false;
        });
      }
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    final date = await showDatePicker(
      context: context,
      initialDate: reminder.scheduledAt.isBefore(DateTime.now())
          ? DateTime.now()
          : reminder.scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(reminder.scheduledAt),
    );

    if (time == null) {
      return;
    }

    final updatedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!updatedDateTime.isAfter(DateTime.now())) {
      _showMessage('Choose a future time.');
      return;
    }

    final title = await _editTitle(reminder);
    if (title == null) {
      return;
    }

    try {
      await ref
          .read(remindersServiceProvider)
          .updateReminder(
            reminder.copyWith(
              scheduledAt: updatedDateTime,
              title: title,
              notePreview: reminder.taskLineIndex == null
                  ? _notePreview(widget.note)
                  : reminder.notePreview,
            ),
          );
      if (mounted) {
        _showMessage('Reminder updated.');
      }
    } catch (error) {
      _showMessage('Could not update reminder: $error');
    }
  }

  Future<void> _toggleReminder(Reminder reminder, bool completed) async {
    try {
      final calendarCleaned = await ref
          .read(remindersServiceProvider)
          .markReminderCompleted(reminder, completed);
      if (mounted) {
        _showMessage(
          completed && reminder.repeat != RepeatType.none
              ? calendarCleaned
                    ? 'Occurrence done. Next reminder scheduled.'
                    : 'Occurrence done. Calendar update will retry later.'
              : completed && !calendarCleaned
              ? 'Reminder completed. Calendar cleanup will retry later.'
              : completed
              ? 'Reminder completed.'
              : 'Reminder reactivated.',
        );
      }
    } catch (error) {
      _showMessage('Could not update reminder: $error');
    }
  }

  Future<void> _stopRepeating(Reminder reminder) async {
    try {
      final calendarCleaned = await ref
          .read(remindersServiceProvider)
          .stopRepeating(reminder);
      if (mounted) {
        _showMessage(
          calendarCleaned
              ? 'Repeating reminder stopped.'
              : 'Reminder stopped. Calendar cleanup will retry later.',
        );
      }
    } catch (error) {
      _showMessage('Could not stop repeating: $error');
    }
  }

  Future<String?> _editTitle(Reminder reminder) async {
    final controller = TextEditingController(
      text: reminder.title.trim().isEmpty
          ? reminderTitleFor(noteContent: reminder.notePreview)
          : reminder.title,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reminder title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      await ref.read(remindersServiceProvider).deleteReminder(reminder);
      if (mounted) {
        _showMessage('Reminder deleted.');
      }
    } catch (error) {
      _showMessage('Could not delete reminder: $error');
    }
  }

  int _notificationId() {
    return DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
  }

  Future<void> _chooseInterval() async {
    final controller = TextEditingController(text: '$_repeatIntervalMinutes');
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Repeat interval'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            helperText: 'Use 15 minutes or more.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 15) {
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Use interval'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes != null && mounted) {
      setState(() => _repeatIntervalMinutes = minutes);
    }
  }

  String _intervalLabel(int minutes) {
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$minutes minutes';
  }

  String _notePreview(Note note) {
    final preview = note.content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Untitled note');

    return preview.length > 80 ? '${preview.substring(0, 80)}...' : preview;
  }

  String _formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatShortDate(value);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date at $time';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.onToggleComplete,
    required this.onEdit,
    this.onStopRepeating,
    required this.onDelete,
    required this.onAddToCalendar,
  });

  final Reminder reminder;
  final ValueChanged<bool?> onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback? onStopRepeating;
  final VoidCallback onDelete;
  final VoidCallback? onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final scheduledDate = localizations.formatShortDate(
      reminder.nextScheduledAt,
    );
    final scheduledTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(reminder.nextScheduledAt),
    );

    final state = reminder.isCompleted
        ? ReminderVisualState.completed
        : reminder.isMissed
        ? ReminderVisualState.missed
        : ReminderVisualState.scheduled;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: reminder.isCompleted,
                  onChanged: onToggleComplete,
                ),
                Expanded(
                  child: Text(
                    reminder.title.trim().isEmpty
                        ? reminder.notePreview
                        : reminder.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: reminder.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                ),
                if (onStopRepeating != null)
                  IconButton(
                    onPressed: onStopRepeating,
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: 'Stop repeating',
                  ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ReminderStatusChip(
              label:
                  '${_repeatLabel(reminder)} | $scheduledDate at $scheduledTime',
              state: state,
            ),
            TextButton.icon(
              onPressed: onAddToCalendar,
              icon: const Icon(Icons.event_outlined),
              label: const Text('Add to calendar'),
            ),
          ],
        ),
      ),
    );
  }

  String _repeatLabel(Reminder reminder) {
    return switch (reminder.repeat) {
      RepeatType.none => 'Once',
      RepeatType.daily => 'Daily',
      RepeatType.weekly => 'Weekly',
      RepeatType.interval =>
        'Every ${_intervalLabel(reminder.repeatIntervalMinutes ?? 30)}',
    };
  }

  String _intervalLabel(int minutes) {
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$minutes min';
  }
}
