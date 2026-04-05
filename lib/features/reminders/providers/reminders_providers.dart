import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/reminders_service.dart';
import '../models/reminder.dart';

final flutterLocalNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
      return FlutterLocalNotificationsPlugin();
    });

final localNotificationsServiceProvider = Provider<LocalNotificationsService>((ref) {
  final plugin = ref.watch(flutterLocalNotificationsPluginProvider);
  return LocalNotificationsService(plugin);
});

final remindersServiceProvider = Provider<RemindersService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final notifications = ref.watch(localNotificationsServiceProvider);
  return RemindersService(firestore, notifications);
});

final remindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final remindersService = ref.watch(remindersServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <Reminder>[]);
      }

      return remindersService.watchReminders(user.uid);
    },
    loading: () => Stream.value(const <Reminder>[]),
    error: (_, _) => Stream.value(const <Reminder>[]),
  );
});

final noteRemindersStreamProvider =
    StreamProvider.family<List<Reminder>, String>((ref, noteId) {
      final authState = ref.watch(authStateChangesProvider);
      final remindersService = ref.watch(remindersServiceProvider);

      return authState.when(
        data: (user) {
          if (user == null) {
            return Stream.value(const <Reminder>[]);
          }

          return remindersService.watchRemindersForNote(user.uid, noteId);
        },
        loading: () => Stream.value(const <Reminder>[]),
        error: (_, _) => Stream.value(const <Reminder>[]),
      );
    });

final nextReminderForNoteProvider =
    Provider.family<AsyncValue<Reminder?>, String>((ref, noteId) {
      final remindersAsync = ref.watch(noteRemindersStreamProvider(noteId));

      return remindersAsync.whenData((reminders) {
        final activeReminders = reminders.where((item) => !item.isCompleted).toList();
        if (activeReminders.isEmpty) {
          return null;
        }

        activeReminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        return activeReminders.first;
      });
    });
