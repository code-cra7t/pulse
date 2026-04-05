import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/reminders/models/repeat_type.dart';

class LocalNotificationsService {
  LocalNotificationsService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String?> _selectedNoteController =
      StreamController<String?>.broadcast();

  String? _selectedNoteId;

  Stream<String?> get selectedNoteStream => _selectedNoteController.stream;
  String? get selectedNoteId => _selectedNoteId;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
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
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

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
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pulse_reminders',
        'Pulse Reminders',
        channelDescription: 'Reminder notifications for notes',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(
        _nextSchedule(scheduledAt, repeat).toUtc(),
        tz.UTC,
      ),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (repeat) {
        RepeatType.none => null,
        RepeatType.daily => DateTimeComponents.time,
        RepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
      },
      payload: noteId,
    );
  }

  Future<void> cancelReminder(int notificationId) {
    return _plugin.cancel(id: notificationId);
  }

  DateTime _nextSchedule(DateTime scheduledAt, RepeatType repeat) {
    final now = DateTime.now();
    var next = scheduledAt;

    if (repeat == RepeatType.none) {
      return next;
    }

    while (!next.isAfter(now)) {
      next = repeat == RepeatType.daily
          ? next.add(const Duration(days: 1))
          : next.add(const Duration(days: 7));
    }

    return next;
  }

  void _handlePayload(String? payload) {
    _selectedNoteId = payload;
    _selectedNoteController.add(payload);
  }
}

@pragma('vm:entry-point')
void _backgroundNotificationTapHandler(NotificationResponse response) {}
