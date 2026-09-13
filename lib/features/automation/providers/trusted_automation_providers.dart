import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_automation_audit_store.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../scheduling/providers/replanning_providers.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/trusted_schedule_executor.dart';
import '../models/automation_audit_entry.dart';
import '../models/automation_preferences.dart';
import 'automation_providers.dart';

final offlineAutomationAuditStoreProvider =
    Provider<OfflineAutomationAuditStore>((ref) {
      final store = OfflineAutomationAuditStore();
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

/// Foreground-only trusted execution. One local move is allowed per fresh
/// replanning snapshot so JotCue always recalculates before considering more.
final trustedAutomationSweepProvider =
    FutureProvider.family<AutomationAuditEntry?, DateTime>((ref, now) async {
      final preferences = ref.watch(automationPreferencesProvider);
      if (preferences.level != AutomationLevel.trusted) {
        return null;
      }
      final user = ref.watch(authStateChangesProvider).asData?.value;
      if (user == null) {
        return null;
      }
      final overview = await ref.watch(adaptiveReplanningProvider(now).future);
      final tasks = ref.watch(tasksProvider);
      return ref
          .watch(trustedScheduleExecutorProvider)
          .executeNext(
            userId: user.uid,
            preferences: preferences,
            overview: overview,
            tasks: tasks,
            now: now,
          );
    });
