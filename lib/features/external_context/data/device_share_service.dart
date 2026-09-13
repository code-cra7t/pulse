import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/shared_capture_payload.dart';

class DeviceShareService {
  DeviceShareService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.tori.pulse/share';

  final MethodChannel _channel;
  final StreamController<SharedCapturePayload> _controller =
      StreamController<SharedCapturePayload>.broadcast();
  bool _initialized = false;
  bool _draining = false;
  bool _drainRequested = false;

  Stream<SharedCapturePayload> get sharedContent => _controller.stream;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_initialized || !_isSupported) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    await drainPending();
  }

  Future<void> drainPending() async {
    if (!_isSupported) {
      return;
    }
    if (_draining) {
      _drainRequested = true;
      return;
    }

    do {
      _drainRequested = false;
      _draining = true;
      try {
        while (true) {
          final raw = await _channel.invokeMapMethod<Object?, Object?>(
            'consumePendingShare',
          );
          if (raw == null) {
            break;
          }
          try {
            _controller.add(SharedCapturePayload.fromMap(raw));
          } on FormatException {
            // Ignore malformed native payloads instead of surfacing bad content.
          }
        }
      } on MissingPluginException {
        // Expected on unsupported/older builds. Sharing remains optional.
      } on PlatformException {
        // A share handoff should never prevent the app from opening normally.
      } finally {
        _draining = false;
      }
    } while (_drainRequested);
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'sharedContentAvailable') {
      await drainPending();
      return null;
    }
    return null;
  }

  Future<void> dispose() async {
    if (_initialized && _isSupported) {
      _channel.setMethodCallHandler(null);
    }
    await _controller.close();
  }
}
