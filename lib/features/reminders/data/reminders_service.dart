import 'package:cloud_firestore/cloud_firestore.dart';

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
    return _remindersCollection.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
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

    await _notificationsService.scheduleReminder(
      notificationId: notificationId,
      title: 'PulseNotes reminder',
      body: notePreview,
      scheduledAt: scheduledAt,
      repeat: repeat,
      noteId: noteId,
    );

    await _calendarEventService.addReminderToCalendar(
      title: 'PulseNotes reminder',
      body: notePreview,
      scheduledAt: scheduledAt,
      repeat: repeat,
    );

    await _remindersCollection.add({
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
  }

  Future<void> updateReminder(Reminder reminder) async {
    await _notificationsService.cancelReminder(reminder.notificationId);
    await _notificationsService.scheduleReminder(
      notificationId: reminder.notificationId,
      title: 'PulseNotes reminder',
      body: reminder.notePreview,
      scheduledAt: reminder.scheduledAt,
      repeat: reminder.repeat,
      noteId: reminder.noteId,
    );

    await _remindersCollection.doc(reminder.id).update(
          reminder.copyWith(updatedAt: DateTime.now()).toMap(),
        );
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
      final reminder = Reminder.fromFirestore(doc).copyWith(
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
