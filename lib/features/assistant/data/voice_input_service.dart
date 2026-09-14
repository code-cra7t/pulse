import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceRecognitionMode { onDevice, system }

enum VoiceInputEventType { listeningChanged, transcript, error }

class VoiceInputEvent {
  const VoiceInputEvent._({
    required this.type,
    this.listening,
    this.transcript,
    this.isFinal = false,
    this.message,
    this.canRetryWithSystem = false,
  });

  factory VoiceInputEvent.listening(bool listening) {
    return VoiceInputEvent._(
      type: VoiceInputEventType.listeningChanged,
      listening: listening,
    );
  }

  factory VoiceInputEvent.transcript(
    String transcript, {
    required bool isFinal,
  }) {
    return VoiceInputEvent._(
      type: VoiceInputEventType.transcript,
      transcript: transcript,
      isFinal: isFinal,
    );
  }

  factory VoiceInputEvent.error(
    String message, {
    bool canRetryWithSystem = false,
  }) {
    return VoiceInputEvent._(
      type: VoiceInputEventType.error,
      message: message,
      canRetryWithSystem: canRetryWithSystem,
    );
  }

  final VoiceInputEventType type;
  final bool? listening;
  final String? transcript;
  final bool isFinal;
  final String? message;
  final bool canRetryWithSystem;
}

abstract class VoiceInputService {
  Stream<VoiceInputEvent> get events;

  bool get isListening;

  bool get isPlatformSupported;

  Future<bool> start({required VoiceRecognitionMode mode});

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}

/// Short, explicit speech recognition for Ask JotCue.
///
/// On-device recognition is requested first. System recognition is a separate
/// user-approved fallback because the operating system or browser may use a
/// network speech service for that mode.
class SpeechToTextVoiceInputService implements VoiceInputService {
  SpeechToTextVoiceInputService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final StreamController<VoiceInputEvent> _events =
      StreamController<VoiceInputEvent>.broadcast(sync: true);

  bool _initialized = false;
  bool _lastListening = false;
  VoiceRecognitionMode _activeMode = VoiceRecognitionMode.onDevice;

  @override
  Stream<VoiceInputEvent> get events => _events.stream;

  @override
  bool get isListening => _speech.isListening;

  @override
  bool get isPlatformSupported {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
  }

  @override
  Future<bool> start({required VoiceRecognitionMode mode}) async {
    if (!isPlatformSupported) {
      _emitError(
        'Voice input is not available on this platform yet. You can keep typing normally.',
      );
      return false;
    }
    if (!await _ensureInitialized()) return false;

    _activeMode = mode;
    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: mode == VoiceRecognitionMode.onDevice,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
        ),
      );
      if (_speech.isListening) {
        _emitListening(true);
      }
      return !_speech.hasError;
    } catch (_) {
      _emitError(
        mode == VoiceRecognitionMode.onDevice
            ? 'On-device speech recognition could not start.'
            : 'System speech recognition could not start.',
        canRetryWithSystem: mode == VoiceRecognitionMode.onDevice,
      );
      _emitListening(false);
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_initialized) return;
    await _speech.stop();
    _emitListening(false);
  }

  @override
  Future<void> cancel() async {
    if (!_initialized) return;
    await _speech.cancel();
    _emitListening(false);
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _events.close();
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      final available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!available) {
        _emitError(
          'Microphone or speech-recognition permission is unavailable. Voice input remains off.',
        );
        return false;
      }
      _initialized = true;
      return true;
    } catch (_) {
      _emitError(
        'Speech recognition is unavailable on this device. You can keep typing normally.',
      );
      return false;
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (_events.isClosed) return;
    _events.add(
      VoiceInputEvent.transcript(
        result.recognizedWords,
        isFinal: result.finalResult,
      ),
    );
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      _emitListening(true);
    } else if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _emitListening(false);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase();
    final permissionDenied =
        code.contains('permission') ||
        code.contains('not_allowed') ||
        code.contains('not allowed') ||
        code.contains('denied');
    final noSpeech =
        code.contains('no_match') ||
        code.contains('no match') ||
        code.contains('speech_timeout') ||
        code.contains('speech timeout');
    final canRetryWithSystem =
        _activeMode == VoiceRecognitionMode.onDevice &&
        !permissionDenied &&
        !noSpeech &&
        (code.contains('network') ||
            code.contains('client') ||
            code.contains('support') ||
            code.contains('language') ||
            code.contains('available') ||
            code.contains('recognizer'));

    final message = permissionDenied
        ? 'Microphone or speech-recognition permission was denied. Voice input remains off.'
        : noSpeech
        ? 'I did not catch any speech. Try the microphone again when you are ready.'
        : _activeMode == VoiceRecognitionMode.onDevice
        ? 'On-device speech recognition is unavailable for this language or device.'
        : 'System speech recognition could not complete this request.';
    _emitError(message, canRetryWithSystem: canRetryWithSystem);
    _emitListening(false);
  }

  void _emitListening(bool listening) {
    if (_lastListening == listening || _events.isClosed) return;
    _lastListening = listening;
    _events.add(VoiceInputEvent.listening(listening));
  }

  void _emitError(String message, {bool canRetryWithSystem = false}) {
    if (_events.isClosed) return;
    _events.add(
      VoiceInputEvent.error(message, canRetryWithSystem: canRetryWithSystem),
    );
  }
}
