import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._firestore, this._storage, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile> getProfileStream(String uid) {
    return _profileDoc(uid).snapshots().map(UserProfile.fromFirestore);
  }

  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _profileDoc(uid).get();
    if (!snapshot.exists) {
      return null;
    }
    return UserProfile.fromFirestore(snapshot);
  }

  Future<void> createProfileIfMissing(User user) async {
    final doc = _profileDoc(user.uid);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      return;
    }

    final now = DateTime.now();
    final displayName = _defaultDisplayName(user);
    debugPrint('[UserProfileRepository] event=create_profile uid=${user.uid}');
    await doc.set(
      UserProfile(
        uid: user.uid,
        displayName: displayName,
        email: user.email ?? '',
        photoUrl: user.photoURL,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    final value = displayName.trim();
    if (value.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    debugPrint('[UserProfileRepository] event=update_name uid=$uid');
    await _profileDoc(uid).set({
      'displayName': value,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    final user = _auth.currentUser;
    if (user?.uid == uid) {
      await user!.updateDisplayName(value);
    }
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    debugPrint('[UserProfileRepository] event=update_photo uid=$uid');
    await _profileDoc(uid).set({
      'photoUrl': photoUrl,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    final user = _auth.currentUser;
    if (user?.uid == uid) {
      await user!.updatePhotoURL(photoUrl);
    }
  }

  Future<String> uploadProfileImage(String uid, XFile image) async {
    final safeName = _safeFileName(image.name);
    final extension = safeName.contains('.')
        ? safeName.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        'users/$uid/profile/avatar_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final reference = _storage.ref().child(path);
    final metadata = SettableMetadata(
      contentType: image.mimeType ?? _contentTypeFor(extension),
    );

    debugPrint(
      '[UserProfileRepository] event=avatar_upload_start uid=$uid path=$path',
    );
    final bytes = await image.readAsBytes();
    await reference.putData(bytes, metadata);
    final url = await reference.getDownloadURL();
    await updatePhotoUrl(uid, url);
    debugPrint('[UserProfileRepository] event=avatar_upload_success uid=$uid');
    return url;
  }

  String _defaultDisplayName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'PulseNotes User';
  }

  String _safeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return normalized.isEmpty ? 'avatar.jpg' : normalized;
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }
}
