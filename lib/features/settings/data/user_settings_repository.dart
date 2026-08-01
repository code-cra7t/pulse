import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_settings.dart';

class UserSettingsRepository {
  UserSettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app');
  }

  Stream<UserSettings> getSettingsStream(String uid) {
    return _settingsDoc(uid).snapshots().map(UserSettings.fromFirestore);
  }

  Future<void> createSettingsIfMissing(String uid) async {
    final doc = _settingsDoc(uid);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      return;
    }

    debugPrint('[UserSettingsRepository] event=create_settings uid=$uid');
    await doc.set(UserSettings.defaults().toMap());
  }

  Future<void> updateThemeMode(String uid, PulseThemeMode themeMode) {
    return _update(uid, {'themeMode': themeMode.name});
  }

  Future<void> updateDefaultNoteTag(String uid, String tag) {
    return _update(uid, {'defaultNoteTag': tag});
  }

  Future<void> updateNotificationsEnabled(String uid, bool enabled) {
    return _update(uid, {'notificationsEnabled': enabled});
  }

  Future<void> updateSmartRemindersEnabled(String uid, bool enabled) {
    return _update(uid, {'smartRemindersEnabled': enabled});
  }

  Future<void> _update(String uid, Map<String, Object?> values) {
    debugPrint(
      '[UserSettingsRepository] event=update_settings uid=$uid values=$values',
    );
    return _settingsDoc(uid).set({
      ...values,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }
}
