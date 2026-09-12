import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/calendar_event_service.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/services/reminder_schedule.dart';
import '../models/reminder.dart';
import '../models/reminder_text.dart';
import '../models/repeat_type.dart';

class RemindersService {
  RemindersService(
    this._firestore,
    this._notificationsService,
    this._calendarEventService,
  );

  final FirebaseFirestore _firestore;
  final LocalNotificationsService _notificationsService;
  final CalendarEventService _calendarEventService;

  CollectionReference<Map<String, dynamic>> get _remindersCollection {
    return _firestore.collection('reminders');
  }

  Stream<List<Reminder>> watchReminders(String userId) {
    return _remindersCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final reminders = snapshot.docs.map(Reminder.fromFirestore).toList();
          reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return reminders;
        });
  }

  Stream<List<Reminder>> watchRemindersForNote(String userId, String noteId) {
    return _remindersCollection
        .where('userId', isEqualTo: userId)
        .where('noteId', isEqualTo: noteId)
        .snapshots()
        .map((snapshot) {
          final reminders = snapshot.docs.map(Reminder.fromFirestore).toList();
          reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return reminders;
        });
  }

  Future<void> restoreActiveNotifications(String userId) async {
    try {
      await _calendarEventService.retryPendingRemovals();
    } catch (error, stackTrace) {
      debugPrint(
        '[Calendar] event=retry_cleanup_failure error=$error\n$stackTrace',
      );
    }
    final snapshot = await _remindersCollection
        .where('userId', isEqualTo: userId)
        .get();
    final now = DateTime.now();
    final reminders = snapshot.docs.map(Reminder.fromFirestore);

    for (final reminder in reminders) {
      if (reminder.isCompleted) {
        await _removeCalendarLinkBestEffort(reminder.id);
        continue;
      }
      if (reminder.repeat == RepeatType.none &&
          !reminder.scheduledAt.isAfter(now)) {
        continue;
      }
      try {
        // Replace the primary schedule without deleting an active snooze.
        await _notificationsService.scheduleReminder(
          notificationId: reminder.notificationId,
          title: _titleFor(reminder),
          body: reminder.notePreview,
          scheduledAt: reminder.scheduledAt,
          repeat: reminder.repeat,
          repeatIntervalMinutes: reminder.repeatIntervalMinutes,
          noteId: reminder.noteId,
        );
        await _updateCalendarLinkBestEffort(reminder);
      } catch (error, stackTrace) {
        debugPrint(
          '[RemindersService] event=restore_notification_failure '
          'reminderId=${reminder.id} error=$error\n$stackTrace',
        );
      }
    }
  }

  Future<Reminder> createReminder({
    required String userId,
    required String noteId,
    int? taskLineIndex,
    String? taskId,
    String? title,
    required String notePreview,
    required DateTime scheduledAt,
    required RepeatType repeat,
    int? repeatIntervalMinutes,
    required int notificationId,
  }) async {
    final now = DateTime.now();
    final resolvedTitle = reminderTitleFor(
      taskText: taskLineIndex == null ? null : notePreview,
      noteTitle: title,
      noteContent: notePreview,
    );
    debugPrint(
      '[RemindersService] event=create_start noteId=$noteId '
      'notificationId=$notificationId at=$scheduledAt repeat=${repeat.value}',
    );

    try {
      await _notificationsService.scheduleReminder(
        notificationId: notificationId,
        title: resolvedTitle,
        body: notePreview,
        scheduledAt: scheduledAt,
        repeat: repeat,
        repeatIntervalMinutes: repeatIntervalMinutes,
        noteId: noteId,
      );
      debugPrint(
        '[RemindersService] event=local_schedule_success '
        'notificationId=$notificationId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[RemindersService] event=local_schedule_failure '
        'notificationId=$notificationId error=$error\n$stackTrace',
      );
      rethrow;
    }

    try {
      final document = _remindersCollection.doc();
      final reminder = Reminder(
        id: document.id,
        userId: userId,
        noteId: noteId,
        taskLineIndex: taskLineIndex,
        taskId: taskId,
        title: resolvedTitle,
        notePreview: notePreview,
        scheduledAt: scheduledAt,
        isCompleted: false,
        repeat: repeat,
        repeatIntervalMinutes: repeatIntervalMinutes,
        notificationId: notificationId,
        createdAt: now,
        updatedAt: now,
      );
      await document.set({
        'userId': userId,
        'noteId': noteId,
        'taskLineIndex': taskLineIndex,
        'taskId': taskId,
        'title': resolvedTitle,
        'notePreview': notePreview,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'isCompleted': false,
        'repeat': repeat.value,
        'repeatIntervalMinutes': repeatIntervalMinutes,
        'notificationId': notificationId,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      debugPrint(
        '[RemindersService] event=create_success reminderId=${document.id} '
        'notificationId=$notificationId',
      );
      return reminder;
    } catch (error, stackTrace) {
      debugPrint(
        '[RemindersService] event=firestore_create_failure '
        'notificationId=$notificationId error=$error\n$stackTrace',
      );
      await _notificationsService.cancelReminder(notificationId);
      rethrow;
    }
  }

  Future<void> addReminderToCalendar(Reminder reminder) {
    return _calendarEventService.addReminderToCalendar(
      reminderId: reminder.id,
      title: _titleFor(reminder),
      body: reminder.notePreview,
      scheduledAt: reminder.scheduledAt,
      repeat: reminder.repeat,
      repeatIntervalMinutes: reminder.repeatIntervalMinutes,
    );
  }

  Future<bool> updateReminder(Reminder reminder) async {
    debugPrint(
      '[RemindersService] event=update_start reminderId=${reminder.id} '
      'notificationId=${reminder.notificationId}',
    );
    try {
      await _notificationsService.cancelReminder(reminder.notificationId);
      await _notificationsService.scheduleReminder(
        notificationId: reminder.notificationId,
        title: _titleFor(reminder),
        body: reminder.notePreview,
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        repeatIntervalMinutes: reminder.repeatIntervalMinutes,
        noteId: reminder.noteId,
      );

      await _remindersCollection
          .doc(reminder.id)
          .update(reminder.copyWith(updatedAt: DateTime.now()).toMap());
      final calendarUpdated = await _updateCalendarLinkBestEffort(reminder);
      debugPrint(
        '[RemindersService] event=update_success reminderId=${reminder.id}',
      );
      return calendarUpdated;
    } catch (error, stackTrace) {
      debugPrint(
        '[RemindersService] event=update_failure reminderId=${reminder.id} '
        'error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> deleteReminder(Reminder reminder) async {
    await _notificationsService.cancelReminder(reminder.notificationId);
    await _remindersCollection.doc(reminder.id).delete();
    await _removeCalendarLinkBestEffort(reminder.id);
  }

  Future<void> deleteRemindersForNote({
    required String userId,
    required String noteId,
  }) async {
    final snapshot = await _remindersCollection
        .where('userId', isEqualTo: userId)
        .where('noteId', isEqualTo: noteId)
        .get();

    for (final doc in snapshot.docs) {
      final reminder = Reminder.fromFirestore(doc);
      await _notificationsService.cancelReminder(reminder.notificationId);
      await doc.reference.delete();
      await _removeCalendarLinkBestEffort(reminder.id);
    }
  }

  Future<bool> markReminderCompleted(Reminder reminder, bool completed) async {
    if (completed && reminder.repeat != RepeatType.none) {
      return completeOccurrence(reminder);
    }
    if (completed) {
      await _notificationsService.cancelReminder(reminder.notificationId);
    } else {
      await _notificationsService.scheduleReminder(
        notificationId: reminder.notificationId,
        title: _titleFor(reminder),
        body: reminder.notePreview,
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        repeatIntervalMinutes: reminder.repeatIntervalMinutes,
        noteId: reminder.noteId,
      );
    }

    await _remindersCollection.doc(reminder.id).update({
      'isCompleted': completed,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    if (completed) {
      return _removeCalendarLinkBestEffort(reminder.id);
    }
    return true;
  }

  Future<bool> completeOccurrence(Reminder reminder) async {
    final now = DateTime.now();
    final next = nextReminderOccurrence(
      scheduledAt: reminder.scheduledAt,
      repeat: reminder.repeat,
      repeatIntervalMinutes: reminder.repeatIntervalMinutes,
      now: reminder.scheduledAt.isAfter(now) ? reminder.scheduledAt : now,
    );
    return updateReminder(reminder.copyWith(scheduledAt: next));
  }

  Future<bool> stopRepeating(Reminder reminder) async {
    await _notificationsService.cancelReminder(reminder.notificationId);
    await _remindersCollection.doc(reminder.id).update({
      'isCompleted': true,
      'repeat': RepeatType.none.value,
      'repeatIntervalMinutes': null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    return _removeCalendarLinkBestEffort(reminder.id);
  }

  Future<void> refreshReminderPreviewsForNote({
    required String userId,
    required String noteId,
    required String notePreview,
  }) async {
    final snapshot = await _remindersCollection
        .where('userId', isEqualTo: userId)
        .where('noteId', isEqualTo: noteId)
        .get();

    for (final doc in snapshot.docs) {
      final existing = Reminder.fromFirestore(doc);
      if (existing.taskLineIndex != null) {
        continue;
      }
      final reminder = existing.copyWith(
        notePreview: notePreview,
        updatedAt: DateTime.now(),
      );

      await doc.reference.update({
        'notePreview': notePreview,
        'updatedAt': Timestamp.fromDate(reminder.updatedAt),
      });

      if (!reminder.isCompleted) {
        await _notificationsService.cancelReminder(reminder.notificationId);
        await _notificationsService.scheduleReminder(
          notificationId: reminder.notificationId,
          title: _titleFor(reminder),
          body: reminder.notePreview,
          scheduledAt: reminder.scheduledAt,
          repeat: reminder.repeat,
          repeatIntervalMinutes: reminder.repeatIntervalMinutes,
          noteId: reminder.noteId,
        );
        await _updateCalendarLinkBestEffort(reminder);
      }
    }
  }

  String _titleFor(Reminder reminder) {
    return reminder.title.trim().isEmpty
        ? reminderTitleFor(
            taskText: reminder.taskLineIndex == null
                ? null
                : reminder.notePreview,
            noteContent: reminder.notePreview,
          )
        : reminder.title.trim();
  }

  Future<bool> _updateCalendarLinkBestEffort(Reminder reminder) async {
    try {
      await _calendarEventService.updateLinkedReminder(
        reminderId: reminder.id,
        title: _titleFor(reminder),
        body: reminder.notePreview,
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        repeatIntervalMinutes: reminder.repeatIntervalMinutes,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[Calendar] event=linked_update_failure reminderId=${reminder.id} '
        'error=$error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> _removeCalendarLinkBestEffort(String reminderId) async {
    try {
      await _calendarEventService.removeReminderFromCalendar(reminderId);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[Calendar] event=linked_remove_failure reminderId=$reminderId '
        'error=$error\n$stackTrace',
      );
      return false;
    }
  }
}
