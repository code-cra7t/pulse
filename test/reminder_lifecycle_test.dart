import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/reminder_schedule.dart';
import 'package:pulse/features/reminders/models/reminder.dart';
import 'package:pulse/features/reminders/models/reminder_text.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';

void main() {
  test('uses task text before the note title for a reminder title', () {
    expect(
      reminderTitleFor(
        taskText: '- [ ] Send the proposal',
        noteTitle: 'Work',
        noteContent: 'Monday notes',
      ),
      'Send the proposal',
    );
  });

  test('uses the note title, then a meaningful first line', () {
    expect(
      reminderTitleFor(noteTitle: 'Groceries', noteContent: 'Buy milk'),
      'Groceries',
    );
    expect(
      reminderTitleFor(noteTitle: ' ', noteContent: '\n  Call Maya  \nLater'),
      'Call Maya',
    );
  });

  test('early recurring completion advances exactly one occurrence', () {
    final reminder = _reminder(
      scheduledAt: DateTime(2026, 9, 8, 18),
      repeat: RepeatType.daily,
    );

    expect(
      nextReminderOccurrence(
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        now: reminder.scheduledAt,
      ),
      DateTime(2026, 9, 9, 18),
    );
  });

  test('overdue recurring completion catches up to the first future date', () {
    final reminder = _reminder(
      scheduledAt: DateTime(2026, 9, 1, 9, 30),
      repeat: RepeatType.weekly,
    );

    expect(
      nextReminderOccurrence(
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        now: DateTime(2026, 9, 8, 10),
      ),
      DateTime(2026, 9, 15, 9, 30),
    );
  });
}

Reminder _reminder({
  required DateTime scheduledAt,
  required RepeatType repeat,
}) {
  return Reminder(
    id: 'reminder-1',
    userId: 'user-1',
    noteId: 'note-1',
    taskLineIndex: null,
    notePreview: 'Preview',
    scheduledAt: scheduledAt,
    isCompleted: false,
    repeat: repeat,
    notificationId: 42,
    createdAt: scheduledAt,
    updatedAt: scheduledAt,
  );
}
