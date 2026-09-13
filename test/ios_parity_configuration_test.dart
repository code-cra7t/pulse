import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Runner declares full calendar access and share callback URL', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('NSCalendarsFullAccessUsageDescription'));
    expect(plist, contains('<string>jotcue</string>'));
    expect(plist, isNot(contains('NSContactsUsageDescription')));
  });

  test('Runner and Share Extension use the same App Group', () {
    final runner = File('ios/Runner/Runner.entitlements').readAsStringSync();
    final share = File(
      'ios/ShareExtension/ShareExtension.entitlements',
    ).readAsStringSync();

    expect(runner, contains('group.com.tori.pulse.share'));
    expect(share, contains('group.com.tori.pulse.share'));
  });

  test('Share Extension is text scoped and embedded in Runner', () {
    final shareInfo = File('ios/ShareExtension/Info.plist').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(shareInfo, contains('com.apple.share-services'));
    expect(shareInfo, contains('NSExtensionActivationSupportsText'));
    expect(project, contains('ShareExtension.appex in Embed App Extensions'));
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),
    );
  });

  test('iOS native bridges keep the established Flutter channel names', () {
    final files = <String>[
      'ios/Runner/IOSCalendarReadBridge.swift',
      'ios/Runner/IOSReminderCalendarBridge.swift',
      'ios/Runner/IOSScheduleCalendarBridge.swift',
      'ios/Runner/IOSShareBridge.swift',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(files, contains('com.tori.pulse/calendar_read'));
    expect(files, contains('com.tori.pulse/calendar_schedule'));
    expect(files, contains('com.tori.pulse/calendar'));
    expect(files, contains('com.tori.pulse/share'));
  });

  test('iOS reminder actions stay on the existing Flutter response path', () {
    final notifications = File(
      'lib/core/services/local_notifications_service.dart',
    ).readAsStringSync();

    expect(notifications, contains('jotcue_reminder_actions_v1'));
    expect(
      notifications,
      contains('categoryIdentifier: _reminderDarwinCategoryId'),
    );
    expect(
      notifications,
      contains('DarwinNotificationActionOption.foreground'),
    );
    expect(notifications, contains("case _snoozeActionId:"));
    expect(notifications, contains("case _dismissActionId:"));
  });

  test('Share Extension keeps a bounded transient handoff queue', () {
    final source = File(
      'ios/ShareExtension/ShareViewController.swift',
    ).readAsStringSync();

    expect(source, contains('maxPendingShares = 8'));
    expect(source, contains('maxTextLength = 20_000'));
    expect(source, contains('jotcue://share'));
    expect(source, isNot(contains('Firestore')));
    expect(source, isNot(contains('Sembast')));
  });
}
