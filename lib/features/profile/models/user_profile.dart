import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;

    return UserProfile(
      uid: data['uid'] as String? ?? snapshot.id,
      displayName: data['displayName'] as String? ?? 'PulseNotes User',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt:
          createdAt?.toDate() ??
          updatedAt?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt?.toDate() ??
          createdAt?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    Object? photoUrl = _unsetPhotoUrl,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: identical(photoUrl, _unsetPhotoUrl)
          ? this.photoUrl
          : photoUrl as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _unsetPhotoUrl = Object();
