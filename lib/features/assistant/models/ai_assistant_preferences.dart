enum AiAssistantMode { localOnly, hybrid }

class AiAssistantPreferences {
  const AiAssistantPreferences({this.mode = AiAssistantMode.localOnly});

  final AiAssistantMode mode;

  bool get usesRemoteGateway => mode == AiAssistantMode.hybrid;

  AiAssistantPreferences copyWith({AiAssistantMode? mode}) {
    return AiAssistantPreferences(mode: mode ?? this.mode);
  }

  Map<String, Object?> toLocalMap() => {'mode': mode.name};

  factory AiAssistantPreferences.fromLocalMap(Map<String, Object?>? data) {
    final raw = data?['mode'] as String?;
    final mode = AiAssistantMode.values.where((value) => value.name == raw);
    return AiAssistantPreferences(
      mode: mode.isEmpty ? AiAssistantMode.localOnly : mode.first,
    );
  }
}
