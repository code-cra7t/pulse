import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_attention_store.dart';
import '../../auth/providers/auth_providers.dart';
import '../../reminders/providers/reminders_providers.dart';
import '../../scheduling/providers/replanning_providers.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/attention_coordinator.dart';
import '../data/attention_engine.dart';
import '../models/attention_preferences.dart';

final offlineAttentionStoreProvider = Provider<OfflineAttentionStore>((ref) {
  final store = OfflineAttentionStore();
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

final attentionPreferencesProvider = StreamProvider<AttentionPreferences>((
  ref,
) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(const AttentionPreferences());
  return ref.watch(offlineAttentionStoreProvider).watchPreferences(user.uid);
});

final attentionCoordinatorProvider = Provider<void>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  final settings = ref.watch(currentUserSettingsProvider).asData?.value;
  final preferences = ref.watch(attentionPreferencesProvider).asData?.value;
  final tasks = ref.watch(tasksProvider);
  if (user == null || settings == null || preferences == null) return;

  final now = DateTime.now();
  final rounded = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  final replanning = ref
      .watch(adaptiveReplanningProvider(rounded))
      .asData
      ?.value;
  final coordinator = AttentionCoordinator(
    engine: const AttentionEngine(),
    store: ref.watch(offlineAttentionStoreProvider),
    notifications: ref.watch(localNotificationsServiceProvider),
  );
  unawaited(
    coordinator
        .reconcile(
          userId: user.uid,
          masterNotificationsEnabled: settings.notificationsEnabled,
          preferences: preferences,
          tasks: tasks,
          replanning: replanning,
          now: now,
        )
        .catchError((Object error, StackTrace stackTrace) {
          // Proactive attention must never make the main workspace fail to render.
        }),
  );
});
