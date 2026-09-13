import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calendar/data/device_schedule_calendar_service.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tori.pulse/calendar_schedule');
  final calls = <MethodCall>[];
  final service = DeviceScheduleCalendarService();
  final block = ScheduleBlock(
    id: 'block-1',
    userId: 'user',
    taskId: 'task-1',
    title: 'Insurance revision',
    startsAt: DateTime(2026, 9, 14, 10),
    endsAt: DateTime(2026, 9, 14, 11, 30),
    createdAt: DateTime(2026, 9, 13),
    updatedAt: DateTime(2026, 9, 13),
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'hasAccess' => true,
            'requestAccess' => true,
            'isLinked' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('checks explicit schedule-calendar write access', () async {
    expect(await service.hasWriteAccess(), isTrue);
    expect(calls.single.method, 'hasAccess');
  });

  test('requests schedule-calendar write access explicitly', () async {
    expect(await service.requestWriteAccess(), isTrue);
    expect(calls.single.method, 'requestAccess');
  });

  test('checks whether a block has a managed calendar link', () async {
    expect(await service.isLinked(block.id), isTrue);
    expect(calls.single.method, 'isLinked');
    expect(calls.single.arguments, {'blockId': 'block-1'});
  });

  test('exports exact block identity and time range', () async {
    await service.upsertBlock(block);

    expect(calls.single.method, 'upsert');
    expect(calls.single.arguments, {
      'blockId': 'block-1',
      'title': 'Insurance revision',
      'description':
          'Planned with JotCue. Calendar edits are not automatically synced back to JotCue.',
      'startsAt': block.startsAt.millisecondsSinceEpoch,
      'endsAt': block.endsAt.millisecondsSinceEpoch,
    });
  });

  test('removal and detach target only the saved block identity', () async {
    await service.removeLinkedBlock(block.id);
    await service.detachBlock(block.id);
    await service.detachAllLinks();

    expect(calls.map((call) => call.method), ['remove', 'detach', 'detachAll']);
    expect(calls[0].arguments, {'blockId': 'block-1'});
    expect(calls[1].arguments, {'blockId': 'block-1'});
  });

  test('unsupported platforms never touch the native write channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(await service.hasWriteAccess(), isFalse);
    expect(await service.requestWriteAccess(), isFalse);
    expect(await service.isLinked(block.id), isFalse);
    await service.removeLinkedBlock(block.id);
    await service.detachBlock(block.id);
    await service.detachAllLinks();
    expect(calls, isEmpty);
  });
}
