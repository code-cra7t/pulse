import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../core/offline/offline_automation_audit_store.dart';
import '../../../core/offline/offline_automation_safety_store.dart';
import '../../../core/offline/offline_note_store.dart';
import '../../../core/offline/offline_project_store.dart';
import '../../../core/offline/offline_schedule_block_store.dart';
import '../../../core/services/calendar_event_service.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../calendar/data/device_schedule_calendar_service.dart';

class AccountDeletionService {
  AccountDeletionService(
    this._auth,
    this._firestore,
    this._storage,
    this._notifications,
    this._offlineNotes,
    this._offlineProjects,
    this._offlineScheduleBlocks,
    this._offlineAutomationAudit,
    this._offlineAutomationSafety, {
    CalendarEventService? calendar,
    DeviceScheduleCalendarService? scheduleCalendar,
  }) : _calendar = calendar ?? CalendarEventService(),
       _scheduleCalendar = scheduleCalendar ?? DeviceScheduleCalendarService();

  static const int _batchSize = 400;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final LocalNotificationsService _notifications;
  final OfflineNoteStore _offlineNotes;
  final OfflineProjectStore _offlineProjects;
  final OfflineScheduleBlockStore _offlineScheduleBlocks;
  final OfflineAutomationAuditStore _offlineAutomationAudit;
  final OfflineAutomationSafetyStore _offlineAutomationSafety;
  final CalendarEventService _calendar;
  final DeviceScheduleCalendarService _scheduleCalendar;

  Future<void> deleteCurrentAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('No email account is currently signed in.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    await _deleteStorageTree(_storage.ref().child('users/${user.uid}'));
    await _deleteQuery(
      _firestore.collection('reminders').where('userId', isEqualTo: user.uid),
      beforeDelete: (id) async {
        try {
          await _calendar.removeReminderFromCalendar(id);
        } catch (error) {
          // Native calendar links retain pending removals for retry. Calendar
          // permission denial must not prevent deleting the user's account.
          debugPrint('[Calendar] account cleanup deferred: $error');
        }
      },
    );
    await _deleteQuery(
      _firestore.collection('notes').where('userId', isEqualTo: user.uid),
    );
    await _deleteQuery(
      _firestore.collection('projects').where('userId', isEqualTo: user.uid),
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('app')
        .delete();
    await _firestore.collection('users').doc(user.uid).delete();

    await _offlineNotes.clearUser(user.uid);
    await _offlineProjects.clearUser(user.uid);
    try {
      await _scheduleCalendar.detachAllLinks();
    } catch (error) {
      debugPrint('[ScheduleCalendar] local link cleanup failed: $error');
    }
    await _offlineScheduleBlocks.clearUser(user.uid);
    await _offlineAutomationAudit.clearUser(user.uid);
    await _offlineAutomationSafety.clearUser(user.uid);
    await _notifications.cancelAllReminders();
    await user.delete();
  }

  Future<void> _deleteQuery(
    Query<Map<String, dynamic>> query, {
    Future<void> Function(String id)? beforeDelete,
  }) async {
    while (true) {
      final snapshot = await query.limit(_batchSize).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        await beforeDelete?.call(document.id);
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteStorageTree(Reference root) async {
    final result = await root.listAll();
    await Future.wait(result.items.map((item) => item.delete()));
    for (final prefix in result.prefixes) {
      await _deleteStorageTree(prefix);
    }
  }
}
