import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/external_context/data/device_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tori.pulse/share');
  final calls = <MethodCall>[];
  final pending = <Object?>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    pending.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method != 'consumePendingShare') return null;
          return pending.isEmpty ? null : pending.removeAt(0);
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('drains cold-start shared text after initialization', () async {
    pending.addAll([
      <Object?, Object?>{
        'text': 'Submit assignment by Friday',
        'mimeType': 'text/plain',
      },
      null,
    ]);
    final service = DeviceShareService();
    final received = <String>[];
    final subscription = service.sharedContent.listen(
      (payload) => received.add(payload.text),
    );

    await service.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(received, ['Submit assignment by Friday']);
    expect(
      calls.where((call) => call.method == 'consumePendingShare'),
      hasLength(2),
    );

    await subscription.cancel();
    await service.dispose();
  });

  test(
    'malformed shared payload is ignored without blocking the next one',
    () async {
      pending.addAll([
        <Object?, Object?>{'text': '   '},
        <Object?, Object?>{'text': 'Review HPC results tomorrow'},
        null,
      ]);
      final service = DeviceShareService();
      final received = <String>[];
      final subscription = service.sharedContent.listen(
        (payload) => received.add(payload.text),
      );

      await service.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(received, ['Review HPC results tomorrow']);

      await subscription.cancel();
      await service.dispose();
    },
  );

  test('initialize is idempotent', () async {
    pending.add(null);
    final service = DeviceShareService();

    await service.initialize();
    final callsAfterFirstInitialize = calls.length;
    await service.initialize();

    expect(calls.length, callsAfterFirstInitialize);
    await service.dispose();
  });

  test('iOS drains the same review-first share queue contract', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    pending.addAll([
      <Object?, Object?>{
        'text': 'https://example.com/research',
        'mimeType': 'text/uri-list',
        'subject': 'Research',
      },
      null,
    ]);
    final service = DeviceShareService();
    final received = <String>[];
    final subscription = service.sharedContent.listen(
      (payload) => received.add(payload.text),
    );

    await service.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(received, ['https://example.com/research']);
    expect(
      calls.where((call) => call.method == 'consumePendingShare'),
      hasLength(2),
    );
    await subscription.cancel();
    await service.dispose();
  });

  test('unsupported desktop platforms never touch the share channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final service = DeviceShareService();

    await service.initialize();

    expect(calls, isEmpty);
    await service.dispose();
  });
}
