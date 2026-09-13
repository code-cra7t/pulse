import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_automation_audit_store.dart';
import '../../../core/offline/offline_automation_safety_store.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../scheduling/providers/replanning_providers.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/trusted_schedule_executor.dart';
import '../data/trusted_schedule_undo_service.dart';
import '../models/automation_audit_entry.dart';
import '../models/automation_preferences.dart';
import '../models/automation_safety_preferences.dart';
import 'automation_providers.dart';

final offlineAutomationAuditStoreProvider =
    Provider<OfflineAutomationAuditStore>((ref) {
      final store = OfflineAutomationAuditStore();
      ref.onDispose(() => unawaited(store.dispose()));
      return store;
    });

final offlineAutomationSafetyStoreProvider =
    Provider<OfflineAutomationSafetyStore>((ref) {
      final store = OfflineAutomationSafetyStore();
      ref.onDispose(() => unawaited(store.dispose()));
      return store;
    });

final automationAuditStreamProvider =
    StreamProvider<List<AutomationAuditEntry>>((ref) {
      final authState = ref.watch(authStateChangesProvider);
      final store = ref.watch(offlineAutomationAuditStoreProvider);
      return authState.when(
        data: (user) {
          if (user == null) {
            return Stream.value(const <AutomationAuditEntry>[]);
          }
          return store.watchEntries(user.uid);
        },
        loading: () => Stream.value(const <AutomationAuditEntry>[]),
        error: (_, _) => Stream.value(const <AutomationAuditEntry>[]),
      );
    });

final automationSafetyPreferencesProvider =
    StreamProvider<AutomationSafetyPreferences>((ref) {
      final authState = ref.watch(authStateChangesProvider);
      final store = ref.watch(offlineAutomationSafetyStoreProvider);
      return authState.when(
        data: (user) {
          if (user == null) {
            return Stream.value(const AutomationSafetyPreferences());
          }
          return store.watchPreferences(user.uid);
        },
        loading: () => Stream.value(const AutomationSafetyPreferences()),
        error: (_, _) => Stream.value(const AutomationSafetyPreferences()),
      );
    });

final trustedScheduleExecutorProvider = Provider<TrustedScheduleExecutor>((
  ref,
) {
  final calendar = ref.watch(deviceScheduleCalendarServiceProvider);
  return TrustedScheduleExecutor(
    policy: ref.watch(automationPolicyProvider),
    scheduleBlocks: ref.watch(scheduleBlocksRepositoryProvider),
    auditStore: ref.watch(offlineAutomationAuditStoreProvider),
    isCalendarLinked: calendar.isLinked,
  );
});

final trustedScheduleUndoServiceProvider = Provider<TrustedScheduleUndoService>(
  (ref) {
    final calendar = ref.watch(deviceScheduleCalendarServiceProvider);
    return TrustedScheduleUndoService(
      scheduleBlocks: ref.watch(scheduleBlocksRepositoryProvider),
      auditStore: ref.watch(offlineAutomationAuditStoreProvider),
      isCalendarLinked: calendar.isLinked,
    );
  },
);

/// Foreground-only trusted execution. One local move is allowed per fresh
/// replanning snapshot so JotCue always recalculates before considering more.
final trustedAutomationSweepProvider =
    FutureProvider.family<AutomationAuditEntry?, DateTime>((ref, now) async {
      final preferences = ref.watch(automationPreferencesProvider);
      if (preferences.level != AutomationLevel.trusted) {
        return null;
      }
      // Keep the stream as an invalidation signal, but read the durable local
      // record before execution so a previous/default AsyncValue can never
      // briefly bypass a persisted pause or exclusion during auth transitions.
      ref.watch(automationSafetyPreferencesProvider);
      final user = ref.watch(authStateChangesProvider).asData?.value;
      if (user == null) {
        return null;
      }
      final safety = await ref
          .watch(offlineAutomationSafetyStoreProvider)
          .readPreferences(user.uid);
      if (safety.paused) {
        return null;
      }
      final overview = await ref.watch(adaptiveReplanningProvider(now).future);
      final tasks = ref.watch(tasksProvider);
      return ref
          .watch(trustedScheduleExecutorProvider)
          .executeNext(
            userId: user.uid,
            preferences: preferences,
            safety: safety,
            overview: overview,
            tasks: tasks,
            now: now,
          );
    });
