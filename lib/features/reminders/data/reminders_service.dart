import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/calendar_event_service.dart';
import '../../../core/services/local_notifications_service.dart';
import '../models/reminder.dart';
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

  Future<void> createReminder({
    required String userId,
    required String noteId,
    int? taskLineIndex,
    required String notePreview,
    required DateTime scheduledAt,
    required RepeatType repeat,
    required int notificationId,
  }) async {
    final now = DateTime.now();
    debugPrint(
      '[RemindersService] event=create_start noteId=$noteId '
      'notificationId=$notificationId at=$scheduledAt repeat=${repeat.value}',
    );

    try {
      await _notificationsService.scheduleReminder(
        notificationId: notificationId,
        title: 'PulseNotes reminder',
        body: notePreview,
        scheduledAt: scheduledAt,
        repeat: repeat,
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
      final document = await _remindersCollection.add({
        'userId': userId,
        'noteId': noteId,
        'taskLineIndex': taskLineIndex,
        'notePreview': notePreview,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'isCompleted': false,
        'repeat': repeat.value,
        'notificationId': notificationId,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      debugPrint(
        '[RemindersService] event=create_success reminderId=${document.id} '
        'notificationId=$notificationId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[RemindersService] event=firestore_create_failure '
        'notificationId=$notificationId error=$error\n$stackTrace',
      );
      await _notificationsService.cancelReminder(notificationId);
      rethrow;
    }

    unawaited(
      _calendarEventService
          .addReminderToCalendar(
            title: 'PulseNotes reminder',
            body: notePreview,
            scheduledAt: scheduledAt,
            repeat: repeat,
          )
          .catchError((Object error) {
            debugPrint('[Calendar] could not add reminder event: $error');
          }),
    );
  }

  Future<void> updateReminder(Reminder reminder) async {
    debugPrint(
      '[RemindersService] event=update_start reminderId=${reminder.id} '
      'notificationId=${reminder.notificationId}',
    );
    try {
      await _notificationsService.cancelReminder(reminder.notificationId);
      await _notificationsService.scheduleReminder(
        notificationId: reminder.notificationId,
        title: 'PulseNotes reminder',
        body: reminder.notePreview,
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        noteId: reminder.noteId,
      );

      await _remindersCollection
          .doc(reminder.id)
          .update(reminder.copyWith(updatedAt: DateTime.now()).toMap());
      debugPrint(
        '[RemindersService] event=update_success reminderId=${reminder.id}',
      );
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
    }
  }

  Future<void> markReminderCompleted(Reminder reminder, bool completed) async {
    if (completed) {
      await _notificationsService.cancelReminder(reminder.notificationId);
    } else {
      await _notificationsService.scheduleReminder(
        notificationId: reminder.notificationId,
        title: 'PulseNotes reminder',
        body: reminder.notePreview,
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        noteId: reminder.noteId,
      );
    }

    await _remindersCollection.doc(reminder.id).update({
      'isCompleted': completed,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
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
      final reminder = Reminder.fromFirestore(
        doc,
      ).copyWith(notePreview: notePreview, updatedAt: DateTime.now());

      await doc.reference.update({
        'notePreview': notePreview,
        'updatedAt': Timestamp.fromDate(reminder.updatedAt),
      });

      if (!reminder.isCompleted) {
        await _notificationsService.cancelReminder(reminder.notificationId);
        await _notificationsService.scheduleReminder(
          notificationId: reminder.notificationId,
          title: 'PulseNotes reminder',
          body: reminder.notePreview,
          scheduledAt: reminder.scheduledAt,
          repeat: reminder.repeat,
          noteId: reminder.noteId,
        );
      }
    }
  }
}
