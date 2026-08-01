import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/user_profile_repository.dart';
import '../models/user_profile.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return Stream.fromFuture(
        repository.createProfileIfMissing(user).catchError((error, stackTrace) {
          debugPrint(
            '[UserProfileProvider] event=create_if_missing_failed '
            'uid=${user.uid} error=$error\n$stackTrace',
          );
        }),
      ).asyncExpand((_) => repository.getProfileStream(user.uid));
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});
