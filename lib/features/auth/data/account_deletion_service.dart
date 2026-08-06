import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/offline/offline_note_store.dart';
import '../../../core/services/local_notifications_service.dart';

class AccountDeletionService {
  AccountDeletionService(
    this._auth,
    this._firestore,
    this._storage,
    this._notifications,
    this._offlineNotes,
  );

  static const int _batchSize = 400;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final LocalNotificationsService _notifications;
  final OfflineNoteStore _offlineNotes;

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
    );
    await _deleteQuery(
      _firestore.collection('notes').where('userId', isEqualTo: user.uid),
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('app')
        .delete();
    await _firestore.collection('users').doc(user.uid).delete();

    await _offlineNotes.clearUser(user.uid);
    await _notifications.cancelAllReminders();
    await user.delete();
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(_batchSize).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
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
