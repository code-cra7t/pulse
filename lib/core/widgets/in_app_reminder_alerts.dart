import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reminders/models/reminder.dart';
import '../../features/reminders/providers/reminders_providers.dart';
import '../services/local_notifications_service.dart';

class InAppReminderAlerts extends ConsumerStatefulWidget {
  const InAppReminderAlerts({
    super.key,
    required this.child,
    required this.messengerKey,
  });

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  ConsumerState<InAppReminderAlerts> createState() =>
      _InAppReminderAlertsState();
}

class _InAppReminderAlertsState extends ConsumerState<InAppReminderAlerts> {
  StreamSubscription<InAppReminderAlert>? _alertSubscription;
  ProviderSubscription<AsyncValue<List<Reminder>>>? _reminderSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      return;
    }

    final notifications = ref.read(localNotificationsServiceProvider);
    _alertSubscription = notifications.inAppAlerts.listen((alert) {
      final messenger = widget.messengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('${alert.title}\n${alert.body}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => notifications.selectNote(alert.noteId),
            ),
          ),
        );
    });
    _reminderSubscription = ref.listenManual(remindersStreamProvider, (
      _,
      next,
    ) {
      next.whenData(notifications.syncWebReminders);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _reminderSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
