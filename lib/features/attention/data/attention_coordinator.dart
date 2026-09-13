import '../../../core/offline/offline_attention_store.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../tasks/models/task.dart';
import '../models/attention_preferences.dart';
import 'attention_engine.dart';

class AttentionCoordinator {
  const AttentionCoordinator({
    required AttentionEngine engine,
    required OfflineAttentionStore store,
    required LocalNotificationsService notifications,
  }) : _engine = engine,
       _store = store,
       _notifications = notifications;

  final AttentionEngine _engine;
  final OfflineAttentionStore _store;
  final LocalNotificationsService _notifications;

  Future<void> reconcile({
    required String userId,
    required bool masterNotificationsEnabled,
    required AttentionPreferences preferences,
    required List<Task> tasks,
    required ReplanningOverview? replanning,
    required DateTime now,
  }) async {
    final previous = await _store.readDelivery(userId);
    if (!masterNotificationsEnabled || !preferences.enabled) {
      for (final id in previous.notificationIds) {
        await _notifications.cancelAttentionNotification(id);
      }
      await _store.writeDelivery(userId, const AttentionDeliveryState());
      return;
    }

    final result = _engine.build(
      now: now,
      preferences: preferences,
      tasks: tasks,
      replanning: replanning,
      lastIssueSignature: previous.lastIssueSignature,
      lastIssueAlertAt: previous.lastIssueAlertAt,
    );
    final fingerprint = _fingerprint(result, preferences, now);
    if (fingerprint == previous.fingerprint) return;

    for (final id in previous.notificationIds) {
      await _notifications.cancelAttentionNotification(id);
    }
    for (final plan in result.plans) {
      await _notifications.scheduleAttentionNotification(plan);
    }

    final scheduledIssue = result.plans.any(
      (plan) => plan.kind.name == 'scheduleIssue',
    );
    await _store.writeDelivery(
      userId,
      AttentionDeliveryState(
        fingerprint: fingerprint,
        notificationIds: result.plans
            .map((plan) => plan.id)
            .toList(growable: false),
        lastIssueSignature: scheduledIssue
            ? result.issueSignature
            : previous.lastIssueSignature,
        lastIssueAlertAt: scheduledIssue ? now : previous.lastIssueAlertAt,
      ),
    );
  }

  String _fingerprint(
    AttentionEngineResult result,
    AttentionPreferences preferences,
    DateTime now,
  ) {
    final day = '${now.year}-${now.month}-${now.day}';
    final planKey = result.plans
        .map(
          (plan) =>
              '${plan.id}:${plan.scheduledAt.toIso8601String()}:${plan.title}',
        )
        .join(';');
    return '$day|${preferences.toLocalMap()}|$planKey';
  }
}
