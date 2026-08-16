import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/reminders/models/repeat_type.dart';
import '../../features/reminders/models/reminder.dart';

class LocalNotificationsService {
  LocalNotificationsService(this._plugin);

  static const String _snoozeActionId = 'snooze';
  static const String _dismissActionId = 'dismiss';
  static const Duration _snoozeDuration = Duration(minutes: 10);
  static const String _reminderChannelId = 'jotcue_reminder_alerts_v3';
  static const String _reminderChannelName = 'JotCue reminder alerts';
  static const String _reminderChannelDescription =
      'Sound, vibration, and pop-up alerts for JotCue reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String?> _selectedNoteController =
      StreamController<String?>.broadcast();
  final StreamController<InAppReminderAlert> _inAppAlertController =
      StreamController<InAppReminderAlert>.broadcast();
  final Map<int, Timer> _webTimers = <int, Timer>{};

  bool _initialized = false;
  bool _permissionsRequested = false;
  String? _selectedNoteId;

  Stream<String?> get selectedNoteStream => _selectedNoteController.stream;
  Stream<InAppReminderAlert> get inAppAlerts => _inAppAlertController.stream;
  String? get selectedNoteId => _selectedNoteId;

  Future<NotificationReadiness> ensureReady() async {
    if (!_initialized) {
      throw StateError('Local notifications have not been initialized.');
    }

    if (kIsWeb) {
      return NotificationReadiness(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
        pendingRequestCount: _webTimers.length,
      );
    }

    await requestPermissions();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    var notificationsAllowed = true;
    var exactAlarmsAllowed = true;

    if (android != null) {
      notificationsAllowed = await android.areNotificationsEnabled() ?? false;
      exactAlarmsAllowed =
          await android.canScheduleExactNotifications() ?? false;
    }

    return NotificationReadiness(
      notificationsAllowed: notificationsAllowed,
      exactAlarmsAllowed: exactAlarmsAllowed,
      pendingRequestCount: await _pendingRequestCount(),
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      _initialized = true;
      debugPrint(
        '[Notifications] web uses in-app alerts; web push is a future enhancement.',
      );
      return;
    }

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
      windows: WindowsInitializationSettings(
        appName: 'JotCue',
        appUserModelId: 'Tori.PulseNotes',
        guid: '0d34cd47-729d-4e5f-bbd7-bd7e5a896624',
      ),
    );

    final initialized = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse:
          _backgroundNotificationTapHandler,
    );
    if (initialized == false) {
      throw StateError('Failed to initialize local notifications.');
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            _reminderChannelName,
            description: _reminderChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

    _initialized = true;
    debugPrint('[Notifications] initialized; timezone=${tz.local.name}');

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handlePayload(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || _permissionsRequested) {
      return;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    bool? notificationPermission;
    bool? exactAlarmPermission;
    if (android != null) {
      notificationPermission = await android.requestNotificationsPermission();
      exactAlarmPermission = await android.requestExactAlarmsPermission();
      debugPrint(
        '[Notifications] permission result: '
        'notifications=$notificationPermission, '
        'exactAlarms=$exactAlarmPermission',
      );
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _permissionsRequested = true;
  }

  Future<void> cancelAllReminders() async {
    for (final timer in _webTimers.values) {
      timer.cancel();
    }
    _webTimers.clear();

    if (!kIsWeb) {
      await _plugin.cancelAll();
    }
  }

  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required RepeatType repeat,
    int? repeatIntervalMinutes,
    required String noteId,
  }) async {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    debugPrint(
      '[Notifications] event=schedule_start platform=$platform '
      'noteId=$noteId notificationId=$notificationId at=$scheduledAt',
    );
    try {
      if (kIsWeb) {
        _scheduleWebAlert(
          notificationId: notificationId,
          title: title,
          body: body,
          scheduledAt: scheduledAt,
          repeat: repeat,
          repeatIntervalMinutes: repeatIntervalMinutes,
          noteId: noteId,
        );
        debugPrint(
          '[Notifications] event=schedule_success platform=web '
          'notificationId=$notificationId',
        );
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.windows &&
          repeat != RepeatType.none) {
        throw UnsupportedError(
          'Recurring reminders are not supported on Windows yet.',
        );
      }

      final readiness = await ensureReady();
      if (!readiness.notificationsAllowed) {
        throw StateError('Notifications are disabled for JotCue.');
      }
      if (!readiness.exactAlarmsAllowed) {
        throw StateError('Exact alarms are disabled for JotCue.');
      }

      if (repeat == RepeatType.interval &&
          (repeatIntervalMinutes == null || repeatIntervalMinutes < 15)) {
        throw ArgumentError.value(
          repeatIntervalMinutes,
          'repeatIntervalMinutes',
          'Interval reminders must repeat every 15 minutes or more.',
        );
      }

      final scheduledDate = _toTzDateTime(
        _nextSchedule(
          scheduledAt,
          repeat,
          repeatIntervalMinutes: repeatIntervalMinutes,
        ),
      );
      debugPrint(
        '[Notifications] scheduling id=$notificationId '
        'at=$scheduledDate timezone=${tz.local.name}',
      );

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          channelDescription: _reminderChannelDescription,
          icon: 'ic_notification',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.reminder,
          ticker: 'JotCue reminder',
          audioAttributesUsage: AudioAttributesUsage.alarm,
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
        windows: const WindowsNotificationDetails(),
      );

      final payload = jsonEncode({
        'notificationId': notificationId,
        'noteId': noteId,
        'title': title,
        'body': body,
      });

      if (repeat == RepeatType.interval) {
        await _plugin.periodicallyShowWithDuration(
          id: notificationId,
          title: title,
          body: body,
          repeatDurationInterval: Duration(minutes: repeatIntervalMinutes!),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
        debugPrint(
          '[Notifications] event=interval_schedule_success '
          'notificationId=$notificationId every=$repeatIntervalMinutes minutes',
        );
        return;
      }

      await _plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: repeat == RepeatType.none
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: defaultTargetPlatform == TargetPlatform.windows
            ? null
            : switch (repeat) {
                RepeatType.none => null,
                RepeatType.daily => DateTimeComponents.time,
                RepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
                RepeatType.interval => null,
              },
        payload: payload,
      );

      final pendingRequests = await _plugin.pendingNotificationRequests();
      final isQueued = pendingRequests.any((item) => item.id == notificationId);
      debugPrint(
        '[Notifications] event=schedule_success platform=$platform '
        'notificationId=$notificationId pending=${pendingRequests.length} '
        'queued=$isQueued',
      );
      if (defaultTargetPlatform == TargetPlatform.android && !isQueued) {
        throw StateError(
          'Reminder was not queued on device. Check notification and exact alarm permissions.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[Notifications] event=schedule_failure platform=$platform '
        'notificationId=$notificationId error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> showImmediateTestNotification() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'System test notifications are unavailable on web.',
      );
    }
    await ensureReady();
    final id = DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
    final platform = defaultTargetPlatform.name;
    debugPrint(
      '[Notifications] event=test_immediate_start platform=$platform id=$id',
    );
    try {
      await _plugin.show(
        id: id,
        title: 'JotCue alert test',
        body: 'JotCue alerts are working on this device.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannelId,
            _reminderChannelName,
            channelDescription: _reminderChannelDescription,
            icon: 'ic_notification',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.reminder,
            ticker: 'JotCue alert test',
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          windows: WindowsNotificationDetails(),
        ),
      );
      debugPrint(
        '[Notifications] event=test_immediate_success platform=$platform id=$id',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Notifications] event=test_immediate_failure platform=$platform '
        'id=$id error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> scheduleTestNotificationIn60Seconds() async {
    final id = DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
    await scheduleReminder(
      notificationId: id,
      title: 'JotCue scheduled test',
      body: 'This notification was scheduled 60 seconds ago.',
      scheduledAt: DateTime.now().add(const Duration(seconds: 60)),
      repeat: RepeatType.none,
      noteId: 'notification-test',
    );
  }

  Future<void> cancelReminder(int notificationId) {
    if (kIsWeb) {
      _webTimers.remove(notificationId)?.cancel();
      return Future<void>.value();
    }
    return _plugin.cancel(id: notificationId);
  }

  void syncWebReminders(Iterable<Reminder> reminders) {
    if (!kIsWeb) {
      return;
    }

    final active = reminders
        .where(
          (reminder) =>
              !reminder.isCompleted &&
              reminder.scheduledAt.isAfter(DateTime.now()),
        )
        .toList();
    final activeIds = active.map((reminder) => reminder.notificationId).toSet();

    for (final id in _webTimers.keys.toList()) {
      if (!activeIds.contains(id)) {
        _webTimers.remove(id)?.cancel();
      }
    }

    for (final reminder in active) {
      if (_webTimers.containsKey(reminder.notificationId)) {
        continue;
      }
      _scheduleWebAlert(
        notificationId: reminder.notificationId,
        title: 'JotCue reminder',
        body: reminder.notePreview,
        scheduledAt: reminder.scheduledAt,
        repeat: reminder.repeat,
        repeatIntervalMinutes: reminder.repeatIntervalMinutes,
        noteId: reminder.noteId,
      );
    }
  }

  void selectNote(String noteId) {
    _handlePayload(noteId);
  }

  void _scheduleWebAlert({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required RepeatType repeat,
    int? repeatIntervalMinutes,
    required String noteId,
  }) {
    _webTimers.remove(notificationId)?.cancel();
    final next = _nextSchedule(
      scheduledAt,
      repeat,
      repeatIntervalMinutes: repeatIntervalMinutes,
    );
    final delay = next.difference(DateTime.now());
    debugPrint('[Notifications] web in-app alert id=$notificationId at=$next');
    _webTimers[notificationId] = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _webTimers.remove(notificationId);
        _inAppAlertController.add(
          InAppReminderAlert(
            notificationId: notificationId,
            noteId: noteId,
            title: title,
            body: body,
          ),
        );
        if (repeat != RepeatType.none) {
          _scheduleWebAlert(
            notificationId: notificationId,
            title: title,
            body: body,
            scheduledAt: next,
            repeat: repeat,
            repeatIntervalMinutes: repeatIntervalMinutes,
            noteId: noteId,
          );
        }
      },
    );
  }

  DateTime _nextSchedule(
    DateTime scheduledAt,
    RepeatType repeat, {
    int? repeatIntervalMinutes,
  }) {
    final now = DateTime.now();
    var next = scheduledAt;

    if (repeat == RepeatType.none) {
      if (!next.isAfter(now)) {
        return now.add(const Duration(minutes: 1));
      }
      return next;
    }

    while (!next.isAfter(now)) {
      next = switch (repeat) {
        RepeatType.daily => next.add(const Duration(days: 1)),
        RepeatType.weekly => next.add(const Duration(days: 7)),
        RepeatType.interval => next.add(
          Duration(minutes: repeatIntervalMinutes ?? 30),
        ),
        RepeatType.none => next,
      };
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
    if (kIsWeb) {
      return _webTimers.length;
    }
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

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
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
        title: data['title'] as String? ?? 'JotCue reminder',
        body: data['body'] as String? ?? '',
      );
    } catch (_) {
      return _NotificationPayload(
        noteId: payload,
        title: 'JotCue reminder',
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

class InAppReminderAlert {
  const InAppReminderAlert({
    required this.notificationId,
    required this.noteId,
    required this.title,
    required this.body,
  });

  final int notificationId;
  final String noteId;
  final String title;
  final String body;
}
