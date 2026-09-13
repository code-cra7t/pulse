import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calendar/data/device_calendar_read_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tori.pulse/calendar_read');
  final calls = <MethodCall>[];
  final service = DeviceCalendarReadService();
  final start = DateTime(2026, 9, 14, 8);
  final end = DateTime(2026, 9, 14, 20);

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'hasAccess' => true,
            'requestAccess' => true,
            'listEvents' => <Object?>[
              <Object?, Object?>{
                'id': '42:1',
                'title': 'Lecture',
                'startsAt': start
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
                'endsAt': start
                    .add(const Duration(hours: 2))
                    .millisecondsSinceEpoch,
                'isAllDay': false,
              },
            ],
            _ => null,
          };
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reports Android calendar read access', () async {
    expect(await service.hasAccess(), isTrue);
    expect(calls.single.method, 'hasAccess');
  });

  test('requests read-only access through the calendar read bridge', () async {
    expect(await service.requestAccess(), isTrue);
    expect(calls.single.method, 'requestAccess');
  });

  test('reads and sorts busy calendar events', () async {
    final events = await service.readBusyEvents(start: start, end: end);

    expect(events, hasLength(1));
    expect(events.single.id, '42:1');
    expect(events.single.title, 'Lecture');
    expect(events.single.startsAt, start.add(const Duration(hours: 1)));
    expect(events.single.endsAt, start.add(const Duration(hours: 2)));
    expect(calls.single.method, 'listEvents');
    expect(calls.single.arguments, {
      'startAt': start.millisecondsSinceEpoch,
      'endAt': end.millisecondsSinceEpoch,
    });
  });

  test(
    'unsupported platforms do not touch the native calendar channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(await service.hasAccess(), isFalse);
      expect(await service.requestAccess(), isFalse);
      expect(await service.readBusyEvents(start: start, end: end), isEmpty);
      expect(calls, isEmpty);
    },
  );

  test('rejects calendar queries longer than 31 days', () async {
    await expectLater(
      service.readBusyEvents(
        start: start,
        end: start.add(const Duration(days: 32)),
      ),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });

  test('rejects invalid calendar query ranges before native access', () async {
    await expectLater(
      service.readBusyEvents(start: end, end: start),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
}
