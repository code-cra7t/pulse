String reminderTitleFor({
  String? taskText,
  String? noteTitle,
  String? noteContent,
}) {
  final candidates = <String?>[
    taskText,
    noteTitle,
    ...?noteContent?.split('\n'),
  ];

  for (final candidate in candidates) {
    final cleaned = _cleanReminderText(candidate);
    if (cleaned.isEmpty) {
      continue;
    }
    if (cleaned.runes.length <= 64) {
      return cleaned;
    }
    return '${String.fromCharCodes(cleaned.runes.take(61))}...';
  }

  return 'Note reminder';
}

String _cleanReminderText(String? value) {
  if (value == null) {
    return '';
  }

  return value
      .trim()
      .replaceFirst(RegExp(r'^[-*]\s+'), '')
      .replaceFirst(RegExp(r'^\[[ xX]\]\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
