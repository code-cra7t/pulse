import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/attention/models/attention_plan.dart';
import '../../features/reminders/models/repeat_type.dart';
import '../../features/reminders/models/reminder.dart';
import '../../features/reminders/models/reminder_text.dart';
import 'reminder_schedule.dart';

class LocalNotificationsService {
  LocalNotificationsService(this._plugin);

  static const String _snoozeActionId = 'snooze';
  static const String _dismissActionId = 'dismiss';
  static const String _reminderDarwinCategoryId = 'jotcue_reminder_actions_v1';
  static const Duration _snoozeDuration = Duration(minutes: 10);
  static const _native = MethodChannel('com.tori.pulse/notifications');
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  int _snoozeId(int id) => id < 0 ? id : -id - 1;
  static const String _reminderChannelId = 'jotcue_reminder_alerts_v3';
  static const String _reminderChannelName = 'JotCue reminder alerts';
  static const String _reminderChannelDescription =
      'Sound, vibration, and pop-up alerts for JotCue reminders';
  static const String _attentionChannelId = 'jotcue_attention_v1';
  static const String _attentionChannelName = 'JotCue attention';
  static const String _attentionChannelDescription =
      'Helpful planning, deadline, Morning Pulse, and Daily Closing cues';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String?> _selectedNoteController =
      StreamController<String?>.broadcast();
  final StreamController<InAppReminderAlert> _inAppAlertController =
      StreamController<InAppReminderAlert>.broadcast();
  final StreamController<AttentionDestination> _attentionDestinationController =
      StreamController<AttentionDestination>.broadcast();
  final Map<int, Timer> _webTimers = <int, Timer>{};

  bool _initialized = false;
  bool _notificationPermissionRequested = false;
  bool _exactAlarmPermissionRequested = false;
  String? _selectedNoteId;
  AttentionDestination? _selectedAttentionDestination;

  Stream<String?> get selectedNoteStream => _selectedNoteController.stream;
  Stream<InAppReminderAlert> get inAppAlerts => _inAppAlertController.stream;
  Stream<AttentionDestination> get attentionDestinations =>
      _attentionDestinationController.stream;
  String? get selectedNoteId => _selectedNoteId;
  AttentionDestination? get selectedAttentionDestination =>
      _selectedAttentionDestination;

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

    final settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _reminderDarwinCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _snoozeActionId,
                'Snooze',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _dismissActionId,
                'Dismiss',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
        ],
      ),
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

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _attentionChannelId,
            _attentionChannelName,
            description: _attentionChannelDescription,
            importance: Importance.defaultImportance,
            playSound: true,
            enableVibration: false,
            showBadge: false,
          ),
        );

    _initialized = true;
    debugPrint('[Notifications] initialized; timezone=${tz.local.name}');

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails?.notificationResponse;
      if (response != null) await _handleNotificationResponse(response);
    }
  }

  Future<void> requestPermissions({bool exactAlarms = true}) async {
    if (kIsWeb) return;
    if (_notificationPermissionRequested &&
        (!exactAlarms || _exactAlarmPermissionRequested)) {
      return;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    bool? notificationPermission;
    bool? exactAlarmPermission;
    if (android != null) {
      if (!_notificationPermissionRequested) {
        notificationPermission = await android.requestNotificationsPermission();
      }
      if (exactAlarms && !_exactAlarmPermissionRequested) {
        exactAlarmPermission = await android.requestExactAlarmsPermission();
      }
      debugPrint(
        '[Notifications] permission result: '
        'notifications=$notificationPermission, '
        'exactAlarms=$exactAlarmPermission',
      );
    }

    if (!_notificationPermissionRequested) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _notificationPermissionRequested = true;
    }
    if (exactAlarms) _exactAlarmPermissionRequested = true;
  }

  Future<void> cancelAllReminders() async {
    for (final timer in _webTimers.values) {
      timer.cancel();
    }
    _webTimers.clear();

    if (!kIsWeb) {
      if (_isAndroid) await _native.invokeMethod<void>('cancelAllIntervals');
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
          categoryIdentifier: _reminderDarwinCategoryId,
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
        if (_isAndroid) {
          // Remove the previous plugin periodic schedule when migrating an ID.
          await _plugin.cancel(id: notificationId);
          await _native.invokeMethod<void>('scheduleInterval', {
            'id': notificationId,
            'title': title,
            'body': body,
            'payload': payload,
            'scheduledAtMillis': scheduledAt.millisecondsSinceEpoch,
            'intervalMillis': Duration(
              minutes: repeatIntervalMinutes!,
            ).inMilliseconds,
          });
          return;
        }
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  Future<void> scheduleAttentionNotification(
    AttentionNotificationPlan plan,
  ) async {
    if (kIsWeb) {
      return;
    }
    if (!_initialized) {
      throw StateError('Local notifications have not been initialized.');
    }
    await requestPermissions(exactAlarms: false);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null &&
        !(await android.areNotificationsEnabled() ?? false)) {
      throw StateError('Notifications are disabled for JotCue.');
    }
    final payload = jsonEncode({
      'type': 'attention',
      'destination': plan.destination.name,
      'kind': plan.kind.name,
      'notificationId': plan.id,
      'title': plan.title,
      'body': plan.body,
    });
    await _plugin.zonedSchedule(
      id: plan.id,
      title: plan.title,
      body: plan.body,
      scheduledDate: _toTzDateTime(plan.scheduledAt),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _attentionChannelId,
          _attentionChannelName,
          channelDescription: _attentionChannelDescription,
          icon: 'ic_notification',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          enableVibration: false,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.status,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: plan.repeatDaily
          ? DateTimeComponents.time
          : null,
      payload: payload,
    );
  }

  Future<void> cancelAttentionNotification(int notificationId) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: notificationId);
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

  Future<void> cancelReminder(int notificationId) async {
    if (kIsWeb) {
      _webTimers.remove(notificationId)?.cancel();
      return;
    }
    if (_isAndroid) {
      await _native.invokeMethod<void>('cancelInterval', {
        'id': notificationId,
      });
    }
    await _plugin.cancel(id: notificationId);
    await _plugin.cancel(id: _snoozeId(notificationId));
  }

  void syncWebReminders(Iterable<Reminder> reminders) {
    if (!kIsWeb) {
      return;
    }

    final active = reminders
        .where(
          (reminder) =>
              !reminder.isCompleted &&
              (reminder.repeat != RepeatType.none ||
                  reminder.scheduledAt.isAfter(DateTime.now())),
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
        title: reminder.title.isEmpty
            ? reminderTitleFor(noteContent: reminder.notePreview)
            : reminder.title,
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
    return nextReminderOccurrence(
      scheduledAt: scheduledAt,
      repeat: repeat,
      now: DateTime.now(),
      repeatIntervalMinutes: repeatIntervalMinutes,
    );
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
    final intervals = _isAndroid
        ? await _native.invokeMethod<int>('pendingIntervalCount') ?? 0
        : 0;
    return pendingRequests.length + intervals;
  }

  Future<void> openAlertSettings() async {
    if (_isAndroid) await _native.invokeMethod<void>('openAlertSettings');
  }

  Future<NotificationAlertStatus> getAlertStatus() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final channels = await android?.getNotificationChannels();
    AndroidNotificationChannel? channel;
    for (final item in channels ?? <AndroidNotificationChannel>[]) {
      if (item.id == _reminderChannelId) channel = item;
    }
    return NotificationAlertStatus(
      notificationsAllowed:
          (await android?.areNotificationsEnabled() ?? true) &&
          channel?.importance != Importance.none,
      exactAlarmsAllowed:
          await android?.canScheduleExactNotifications() ?? true,
      soundEnabled: channel?.playSound,
      vibrationEnabled: channel?.enableVibration,
      pendingRequestCount: await _pendingRequestCount(),
    );
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
    if (payload?.attentionDestination != null) {
      _selectedAttentionDestination = payload!.attentionDestination!;
      _attentionDestinationController.add(payload.attentionDestination!);
      return;
    }

    switch (response.actionId) {
      case _snoozeActionId:
        if (payload == null || notificationId == null) {
          return;
        }
        // Removing a delivered alert must not cancel its recurring schedule.
        if (_isAndroid) {
          await _native.invokeMethod<void>('dismissAlert', {
            'id': notificationId,
          });
        }
        await scheduleReminder(
          notificationId: _snoozeId(notificationId),
          title: payload.title,
          body: payload.body,
          scheduledAt: DateTime.now().add(_snoozeDuration),
          repeat: RepeatType.none,
          noteId: payload.noteId,
        );
        return;
      case _dismissActionId:
        if (notificationId != null) {
          if (_isAndroid) {
            await _native.invokeMethod<void>('dismissAlert', {
              'id': notificationId,
            });
          }
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
        attentionDestination: data['type'] == 'attention'
            ? _attentionDestinationFromName(data['destination'] as String?)
            : null,
      );
    } catch (_) {
      return _NotificationPayload(
        noteId: payload,
        title: 'JotCue reminder',
        body: '',
      );
    }
  }

  AttentionDestination? _attentionDestinationFromName(String? value) {
    for (final destination in AttentionDestination.values) {
      if (destination.name == value) return destination;
    }
    return null;
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
    this.attentionDestination,
  });

  final int? notificationId;
  final String noteId;
  final String title;
  final String body;
  final AttentionDestination? attentionDestination;
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

class NotificationAlertStatus {
  const NotificationAlertStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.pendingRequestCount,
  });
  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;
  final bool? soundEnabled;
  final bool? vibrationEnabled;
  final int pendingRequestCount;
}

class InAppReminderAlert {
  const InAppReminderAlert({
    required this.notificationId,
    required this.noteId,
    required this.title,
    required this.body,
    this.attentionDestination,
  });

  final int notificationId;
  final String noteId;
  final String title;
  final String body;
  final AttentionDestination? attentionDestination;
}
