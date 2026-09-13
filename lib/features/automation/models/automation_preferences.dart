enum AutomationLevel {
  observe,
  suggest,
  approval,
  trusted;

  static AutomationLevel fromValue(String? value) {
    return AutomationLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => AutomationLevel.suggest,
    );
  }
}

class AutomationPreferences {
  const AutomationPreferences({required this.level});

  final AutomationLevel level;

  factory AutomationPreferences.defaults() {
    return const AutomationPreferences(level: AutomationLevel.suggest);
  }

  factory AutomationPreferences.fromMap(Object? raw) {
    if (raw is! Map) {
      return AutomationPreferences.defaults();
    }
    final data = Map<String, dynamic>.from(raw);
    return AutomationPreferences(
      level: AutomationLevel.fromValue(data['level'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {'level': level.name};

  AutomationPreferences copyWith({AutomationLevel? level}) {
    return AutomationPreferences(level: level ?? this.level);
  }
}
