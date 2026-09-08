import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/alarm_handoff_service.dart';
import 'package:pulse/core/services/local_notifications_service.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
  const native = MethodChannel('com.tori.pulse/notifications');
  const timezone = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  Map<String, Object?>? launchResponse;
  late LocalNotificationsService service;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    launchResponse = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Berlin');
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      return call.method == 'pendingIntervalCount' ? 1 : null;
    });
    messenger.setMockMethodCallHandler(plugin, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
        case 'requestNotificationsPermission':
        case 'requestExactAlarmsPermission':
        case 'areNotificationsEnabled':
        case 'canScheduleExactNotifications':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {
            'notificationLaunchedApp': launchResponse != null,
            'notificationResponse': launchResponse,
          };
        case 'pendingNotificationRequests':
          return [
            {'id': 42},
            {'id': -43},
          ];
        default:
          return null;
      }
    });
    service = LocalNotificationsService(FlutterLocalNotificationsPlugin());
    await service.initialize();
    calls.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [plugin, native, timezone]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'Android custom recurrence reaches native scheduler with original start',
    () async {
      final start = DateTime.now().add(const Duration(hours: 3));
      await service.scheduleReminder(
        notificationId: 42,
        title: 'Stretch',
        body: '',
        scheduledAt: start,
        repeat: RepeatType.interval,
        repeatIntervalMinutes: 90,
        noteId: 'note-1',
      );
      final call = calls.singleWhere((c) => c.method == 'scheduleInterval');
      expect(call.arguments['scheduledAtMillis'], start.millisecondsSinceEpoch);
      expect(call.arguments['intervalMillis'], 90 * 60 * 1000);
      expect(
        calls.where((c) => c.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
    },
  );

  test(
    'completing a reminder cancels native, plugin and snoozed schedules',
    () async {
      await service.cancelReminder(42);
      expect(
        calls.where((c) => c.method == 'cancelInterval').single.arguments,
        {'id': 42},
      );
      expect(
        calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id']),
        containsAll([42, -43]),
      );
    },
  );

  test(
    'cold-launch snooze uses a child notification and preserves the series',
    () async {
      launchResponse = {
        'notificationId': 42,
        'actionId': 'snooze',
        'notificationResponseType': 1,
        'payload': jsonEncode({
          'notificationId': 42,
          'noteId': 'note-1',
          'title': 'Stretch',
          'body': '',
        }),
      };
      await LocalNotificationsService(
        FlutterLocalNotificationsPlugin(),
      ).initialize();
      expect(calls.where((c) => c.method == 'cancelInterval'), isEmpty);
      expect(calls.where((c) => c.method == 'cancel'), isEmpty);
      expect(
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments['id'],
        -43,
      );
      expect(calls.singleWhere((c) => c.method == 'dismissAlert').arguments, {
        'id': 42,
      });
    },
  );

  test('Clock handoff only represents the next occurrence of a time', () {
    final alarm = AlarmHandoffService();
    final now = DateTime(2026, 9, 8, 12);
    expect(alarm.canRepresentDate(DateTime(2026, 9, 8, 14), now: now), isTrue);
    expect(alarm.canRepresentDate(DateTime(2026, 9, 9, 8), now: now), isTrue);
    expect(
      alarm.canRepresentDate(DateTime(2026, 9, 10, 14), now: now),
      isFalse,
    );
  });
}
