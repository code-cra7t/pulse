import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/calendar_event_service.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tori.pulse/calendar');
  final calls = <MethodCall>[];
  final service = CalendarEventService();
  final date = DateTime(2026, 9, 9, 10);

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'managed export preserves reminder identity and custom recurrence',
    () async {
      await service.addReminderToCalendar(
        reminderId: 'reminder-1',
        title: 'Water plants',
        body: 'Kitchen plants',
        scheduledAt: date,
        repeat: RepeatType.interval,
        repeatIntervalMinutes: 90,
      );
      expect(calls.single.method, 'upsert');
      expect(calls.single.arguments, {
        'reminderId': 'reminder-1',
        'title': 'Water plants',
        'body': 'Kitchen plants',
        'scheduledAt': date.millisecondsSinceEpoch,
        'repeat': 'interval',
        'repeatIntervalMinutes': 90,
      });
    },
  );

  test(
    'editing requests update-only rather than creating another event',
    () async {
      await service.updateLinkedReminder(
        reminderId: 'reminder-1',
        title: 'Water plants',
        body: '',
        scheduledAt: date,
        repeat: RepeatType.daily,
      );
      expect(calls.single.method, 'updateLinked');
    },
  );

  test('completion removes only the saved reminder link', () async {
    await service.removeReminderFromCalendar('reminder-1');
    expect(calls.single.method, 'remove');
    expect(calls.single.arguments, {'reminderId': 'reminder-1'});
  });

  test('iOS reminder calendar links use the managed native bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await service.addReminderToCalendar(
      reminderId: 'reminder-1',
      title: 'Water plants',
      body: '',
      scheduledAt: date,
      repeat: RepeatType.daily,
    );
    await service.updateLinkedReminder(
      reminderId: 'reminder-1',
      title: 'Water plants',
      body: '',
      scheduledAt: date,
      repeat: RepeatType.weekly,
    );
    await service.removeReminderFromCalendar('reminder-1');

    expect(calls.map((call) => call.method), [
      'upsert',
      'updateLinked',
      'remove',
    ]);
  });

  test(
    'iOS preserves the existing custom-interval calendar limitation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await expectLater(
        service.addReminderToCalendar(
          reminderId: 'reminder-1',
          title: 'Water plants',
          body: '',
          scheduledAt: date,
          repeat: RepeatType.interval,
          repeatIntervalMinutes: 90,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'unmanaged desktop platforms do not attempt linked event deletion',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await service.removeReminderFromCalendar('reminder-1');
      expect(calls, isEmpty);
    },
  );

  test(
    'permission failure is surfaced, not reported as successful export',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'CALENDAR_PERMISSION');
          });
      await expectLater(
        service.addReminderToCalendar(
          reminderId: 'reminder-1',
          title: 'Water plants',
          body: '',
          scheduledAt: date,
          repeat: RepeatType.none,
        ),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
