import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens the Android Clock app with an alarm time pre-filled.
///
/// The Clock app remains responsible for the final confirmation so JotCue never
/// creates a native alarm without the user seeing it.
class AlarmHandoffService {
  static const MethodChannel _channel = MethodChannel('com.tori.pulse/alarm');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool canRepresentDate(DateTime scheduledAt, {DateTime? now}) {
    final current = now ?? DateTime.now();
    var next = DateTime(
      current.year,
      current.month,
      current.day,
      scheduledAt.hour,
      scheduledAt.minute,
    );
    if (!next.isAfter(current)) {
      next = DateTime(
        current.year,
        current.month,
        current.day + 1,
        scheduledAt.hour,
        scheduledAt.minute,
      );
    }
    return scheduledAt.isAfter(current) &&
        scheduledAt.year == next.year &&
        scheduledAt.month == next.month &&
        scheduledAt.day == next.day;
  }

  Future<void> openAlarm({
    required DateTime scheduledAt,
    required String label,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Phone alarm handoff is Android-only.');
    }
    if (!canRepresentDate(scheduledAt)) {
      throw UnsupportedError(
        'Clock supports the next occurrence of a time. Use a JotCue reminder for this future date.',
      );
    }

    final opened = await _channel.invokeMethod<bool>('setAlarm', {
      'hour': scheduledAt.hour,
      'minute': scheduledAt.minute,
      'label': label,
    });
    if (opened != true) {
      throw StateError('No compatible Clock app was found.');
    }
  }
}
