import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/calendar_busy_event.dart';

class DeviceCalendarReadService {
  static const maxQueryRange = Duration(days: 31);
  static const _channel = MethodChannel('com.tori.pulse/calendar_read');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasAccess() async {
    if (!isSupported) {
      return false;
    }
    return await _channel.invokeMethod<bool>('hasAccess') ?? false;
  }

  Future<bool> requestAccess() async {
    if (!isSupported) {
      return false;
    }
    return await _channel.invokeMethod<bool>('requestAccess') ?? false;
  }

  Future<List<CalendarBusyEvent>> readBusyEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!isSupported) {
      return const <CalendarBusyEvent>[];
    }
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
    if (end.difference(start) > maxQueryRange) {
      throw ArgumentError.value(
        end,
        'end',
        'calendar queries may span at most 31 days',
      );
    }

    final raw = await _channel.invokeListMethod<Object?>('listEvents', {
      'startAt': start.millisecondsSinceEpoch,
      'endAt': end.millisecondsSinceEpoch,
    });

    if (raw == null || raw.isEmpty) {
      return const <CalendarBusyEvent>[];
    }

    final events = <CalendarBusyEvent>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final event = CalendarBusyEvent.fromPlatformMap(
        Map<Object?, Object?>.from(item),
      );
      if (event.isValid) {
        events.add(event);
      }
    }
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return List.unmodifiable(events);
  }
}
