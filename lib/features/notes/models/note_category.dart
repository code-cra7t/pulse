class NoteCategory {
  const NoteCategory._();

  static const defaults = <String>[
    'Work',
    'Personal',
    'Ideas',
    'Study',
    'To-Do',
    'Reminders',
  ];

  static String? normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    for (final category in defaults) {
      if (category.toLowerCase() == trimmed.toLowerCase()) {
        return category;
      }
    }
    return trimmed;
  }

  static String? fromTags(Iterable<String> tags) {
    for (final tag in tags) {
      final normalized = normalize(tag);
      if (normalized != null && defaults.contains(normalized)) {
        return normalized;
      }
    }
    return null;
  }
}
