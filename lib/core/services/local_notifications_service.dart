import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/reminders/models/repeat_type.dart';

class LocalNotificationsService {
  LocalNotificationsService(this._plugin);

  static const String _snoozeActionId = 'snooze';
  static const String _dismissActionId = 'dismiss';
  static const Duration _snoozeDuration = Duration(minutes: 10);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String?> _selectedNoteController =
      StreamController<String?>.broadcast();

  String? _selectedNoteId;

  Stream<String?> get selectedNoteStream => _selectedNoteController.stream;
  String? get selectedNoteId => _selectedNoteId;

  Future<NotificationReadiness> ensureReady() async {
    await requestPermissions();

    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();

    var notificationsAllowed = true;
    var exactAlarmsAllowed = true;

    if (android != null) {
      try {
        final enabled = await (android as dynamic).areNotificationsEnabled();
        if (enabled is bool) {
          notificationsAllowed = enabled;
        }
      } catch (_) {}

      try {
        final exactAllowed = await (android as dynamic).canScheduleExactNotifications();
        if (exactAllowed is bool) {
          exactAlarmsAllowed = exactAllowed;
        }
      } catch (_) {}
    }

    return NotificationReadiness(
      notificationsAllowed: notificationsAllowed,
      exactAlarmsAllowed: exactAlarmsAllowed,
      pendingRequestCount: await _pendingRequestCount(),
    );
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse:
          _backgroundNotificationTapHandler,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handlePayload(launchDetails?.notificationResponse?.payload);
    }

    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    if (android != null) {
      try {
        await (android as dynamic).requestPermission();
      } catch (_) {
        await android.requestNotificationsPermission();
      }
    }
    try {
      await (android as dynamic).requestExactAlarmsPermission();
    } catch (_) {}

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required RepeatType repeat,
    required String noteId,
  }) async {
    final readiness = await ensureReady();
    if (!readiness.notificationsAllowed) {
      throw StateError('Notifications are disabled for PulseNotes.');
    }
    if (!readiness.exactAlarmsAllowed) {
      throw StateError('Exact alarms are disabled for PulseNotes.');
    }

    final scheduledDate = _toTzDateTime(_nextSchedule(scheduledAt, repeat));

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pulse_reminders',
        'Pulse Reminders',
        channelDescription: 'Reminder notifications for notes',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            _snoozeActionId,
            'Snooze',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            _dismissActionId,
            'Dismiss',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: repeat == RepeatType.none
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (repeat) {
        RepeatType.none => null,
        RepeatType.daily => DateTimeComponents.time,
        RepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
      },
      payload: jsonEncode({
        'notificationId': notificationId,
        'noteId': noteId,
        'title': title,
        'body': body,
      }),
    );

    final pendingRequests = await _plugin.pendingNotificationRequests();
    final isQueued = pendingRequests.any((item) => item.id == notificationId);
    if (!isQueued) {
      throw StateError(
        'Reminder was not queued on device. Check notification and exact alarm permissions.',
      );
    }
  }

  Future<void> cancelReminder(int notificationId) {
    return _plugin.cancel(id: notificationId);
  }

  DateTime _nextSchedule(DateTime scheduledAt, RepeatType repeat) {
    final now = DateTime.now();
    var next = scheduledAt;

    if (repeat == RepeatType.none) {
      if (!next.isAfter(now)) {
        return now.add(const Duration(minutes: 1));
      }
      return next;
    }

    while (!next.isAfter(now)) {
      next = repeat == RepeatType.daily
          ? next.add(const Duration(days: 1))
          : next.add(const Duration(days: 7));
    }

    return next;
  }

  tz.TZDateTime _toTzDateTime(DateTime value) {
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  Future<int> _pendingRequestCount() async {
    final pendingRequests = await _plugin.pendingNotificationRequests();
    return pendingRequests.length;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } on PlatformException {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final payload = _parsePayload(response.payload);
    final notificationId = response.id ?? payload?.notificationId;

    switch (response.actionId) {
      case _snoozeActionId:
        if (payload == null || notificationId == null) {
          return;
        }
        await _plugin.cancel(id: notificationId);
        await scheduleReminder(
          notificationId: notificationId,
          title: payload.title,
          body: payload.body,
          scheduledAt: DateTime.now().add(_snoozeDuration),
          repeat: RepeatType.none,
          noteId: payload.noteId,
        );
        return;
      case _dismissActionId:
        if (notificationId != null) {
          await _plugin.cancel(id: notificationId);
        }
        return;
      default:
        _handlePayload(payload?.noteId);
    }
  }

  _NotificationPayload? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return _NotificationPayload(
        notificationId: data['notificationId'] as int?,
        noteId: data['noteId'] as String? ?? '',
        title: data['title'] as String? ?? 'PulseNotes reminder',
        body: data['body'] as String? ?? '',
      );
    } catch (_) {
      return _NotificationPayload(
        noteId: payload,
        title: 'PulseNotes reminder',
        body: '',
      );
    }
  }

  void _handlePayload(String? noteId) {
    _selectedNoteId = noteId;
    _selectedNoteController.add(noteId);
  }
}

@pragma('vm:entry-point')
void _backgroundNotificationTapHandler(NotificationResponse response) {}

class _NotificationPayload {
  const _NotificationPayload({
    this.notificationId,
    required this.noteId,
    required this.title,
    required this.body,
  });

  final int? notificationId;
  final String noteId;
  final String title;
  final String body;
}

class NotificationReadiness {
  const NotificationReadiness({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.pendingRequestCount,
  });

  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;
  final int pendingRequestCount;
}
