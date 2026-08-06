import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../notes/providers/notes_providers.dart';
import '../../reminders/providers/reminders_providers.dart';
import '../data/account_deletion_service.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
    ref.watch(localNotificationsServiceProvider),
    ref.watch(offlineNoteStoreProvider),
  );
});
