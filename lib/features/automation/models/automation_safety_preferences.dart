class AutomationSafetyPreferences {
  const AutomationSafetyPreferences({
    this.paused = false,
    this.excludedTaskIds = const <String>{},
    this.excludedProjectIds = const <String>{},
  });

  final bool paused;
  final Set<String> excludedTaskIds;
  final Set<String> excludedProjectIds;

  int get exclusionCount => excludedTaskIds.length + excludedProjectIds.length;

  bool excludesTask(String taskId) => excludedTaskIds.contains(taskId);

  bool excludesProject(String? projectId) =>
      projectId != null && excludedProjectIds.contains(projectId);

  AutomationSafetyPreferences copyWith({
    bool? paused,
    Set<String>? excludedTaskIds,
    Set<String>? excludedProjectIds,
  }) {
    return AutomationSafetyPreferences(
      paused: paused ?? this.paused,
      excludedTaskIds: excludedTaskIds ?? this.excludedTaskIds,
      excludedProjectIds: excludedProjectIds ?? this.excludedProjectIds,
    );
  }

  factory AutomationSafetyPreferences.fromLocalMap(Object? raw) {
    if (raw is! Map) {
      return const AutomationSafetyPreferences();
    }
    final data = Map<String, dynamic>.from(raw);
    return AutomationSafetyPreferences(
      paused: data['paused'] is bool ? data['paused'] as bool : false,
      excludedTaskIds: _stringSet(data['excludedTaskIds']),
      excludedProjectIds: _stringSet(data['excludedProjectIds']),
    );
  }

  Map<String, dynamic> toLocalMap() {
    final tasks = excludedTaskIds.toList()..sort();
    final projects = excludedProjectIds.toList()..sort();
    return {
      'paused': paused,
      'excludedTaskIds': tasks,
      'excludedProjectIds': projects,
    };
  }
}

Set<String> _stringSet(Object? raw) {
  if (raw is! Iterable) {
    return const <String>{};
  }
  return raw
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .toSet();
}
