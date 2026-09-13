import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../scheduling/models/schedule_block.dart';

class DeviceScheduleCalendarService {
  static const _channel = MethodChannel('com.tori.pulse/calendar_schedule');

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> hasWriteAccess() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasAccess') ?? false;
  }

  Future<bool> requestWriteAccess() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('requestAccess') ?? false;
  }

  Future<bool> isLinked(String blockId) async {
    if (!isSupported || blockId.isEmpty) return false;
    return await _channel.invokeMethod<bool>('isLinked', {
          'blockId': blockId,
        }) ??
        false;
  }

  Future<void> upsertBlock(ScheduleBlock block) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Managed JotCue schedule calendar entries are unavailable on this platform.',
      );
    }
    if (!block.isValid) {
      throw ArgumentError('The planned block must end after it starts.');
    }
    await _channel.invokeMethod<void>('upsert', {
      'blockId': block.id,
      'title': block.title,
      'description':
          'Planned with JotCue. Calendar edits are not automatically synced back to JotCue.',
      'startsAt': block.startsAt.millisecondsSinceEpoch,
      'endsAt': block.endsAt.millisecondsSinceEpoch,
    });
  }

  Future<void> removeLinkedBlock(String blockId) async {
    if (!isSupported || blockId.isEmpty) return;
    await _channel.invokeMethod<void>('remove', {'blockId': blockId});
  }

  Future<void> detachBlock(String blockId) async {
    if (!isSupported || blockId.isEmpty) return;
    await _channel.invokeMethod<void>('detach', {'blockId': blockId});
  }

  /// Clears JotCue's ownership metadata without deleting calendar events.
  Future<void> detachAllLinks() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('detachAll');
  }
}
