import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../notes/models/note.dart';
import '../models/reminder.dart';
import '../models/repeat_type.dart';
import '../providers/reminders_providers.dart';

class NoteRemindersSheet extends ConsumerStatefulWidget {
  const NoteRemindersSheet({
    super.key,
    required this.note,
  });

  final Note note;

  @override
  ConsumerState<NoteRemindersSheet> createState() => _NoteRemindersSheetState();
}

class _NoteRemindersSheetState extends ConsumerState<NoteRemindersSheet> {
  DateTime? _selectedDateTime;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(noteRemindersStreamProvider(widget.note.id));
    final reminders = remindersAsync.asData?.value ?? const <Reminder>[];

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
              Text(
                'Reminders',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _notePreview(widget.note),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: Text(
                  _selectedDateTime == null
                      ? 'Choose date and time'
                      : _formatDateTime(_selectedDateTime!),
                ),
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
              if (remindersAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (remindersAsync.hasError)
                Text('Unable to load reminders: ${remindersAsync.error}')
              else if (reminders.isEmpty)
                Text(
                  'No reminders for this note yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                          onDelete: () => _deleteReminder(reminder),
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

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      _showMessage('You need to be signed in.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(remindersServiceProvider).createReminder(
            userId: user.uid,
            noteId: widget.note.id,
            notePreview: _notePreview(widget.note),
            scheduledAt: selectedDateTime,
            repeat: RepeatType.none,
            notificationId: _notificationId(),
          );

      if (mounted) {
        setState(() {
          _selectedDateTime = null;
        });
        _showMessage('Reminder added.');
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

  Future<void> _editReminder(Reminder reminder) async {
    final date = await showDatePicker(
      context: context,
      initialDate: reminder.scheduledAt,
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

    try {
      await ref.read(remindersServiceProvider).updateReminder(
            reminder.copyWith(
              scheduledAt: updatedDateTime,
              notePreview: _notePreview(widget.note),
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
      await ref.read(remindersServiceProvider).markReminderCompleted(
            reminder,
            completed,
          );
      if (mounted) {
        _showMessage(completed ? 'Reminder completed.' : 'Reminder reactivated.');
      }
    } catch (error) {
      _showMessage('Could not update reminder: $error');
    }
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

  String _notePreview(Note note) {
    final preview = note.content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Untitled note');

    return preview.length > 80 ? '${preview.substring(0, 80)}...' : preview;
  }

  String _formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatShortDate(value);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
    );
    return '$date at $time';
  }

  void _showMessage(String message) {
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
    required this.onDelete,
  });

  final Reminder reminder;
  final ValueChanged<bool?> onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final scheduledDate = localizations.formatShortDate(reminder.scheduledAt);
    final scheduledTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(reminder.scheduledAt),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Checkbox(
          value: reminder.isCompleted,
          onChanged: onToggleComplete,
        ),
        title: Text(reminder.notePreview),
        subtitle: Text(
          '$scheduledDate at $scheduledTime | ${reminder.repeat.value}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
