class ProactivePulseSnapshot {
  const ProactivePulseSnapshot({
    required this.generatedAt,
    required this.morningMessage,
    required this.focusMessage,
    required this.closingMessage,
    required this.attentionMessage,
    this.blockedMessage,
    this.timingMessage,
    this.recoveryMessage,
  });

  final DateTime generatedAt;

  /// Concise intervention for Morning Pulse / today's snapshot.
  final String morningMessage;

  /// Short explanation of what matters most now and why.
  final String focusMessage;

  /// Contextual close-out guidance for Daily Closing.
  final String closingMessage;

  /// Summary suitable for an in-app attention surface.
  final String attentionMessage;

  /// Explicitly calls out work that is blocked and can stay out of focus.
  final String? blockedMessage;

  /// Best deterministic execution window, when one is known.
  final String? timingMessage;

  /// What slipped and how to recover it, when replanning knows a safe window.
  final String? recoveryMessage;

  bool get hasBlockedWork => blockedMessage != null;
  bool get hasRecovery => recoveryMessage != null;
}
