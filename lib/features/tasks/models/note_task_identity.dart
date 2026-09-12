class NoteTaskIdentity {
  const NoteTaskIdentity({
    required this.id,
    required this.lineIndex,
    required this.text,
  });

  final String id;
  final int lineIndex;
  final String text;

  String get normalizedText => normalizeTaskIdentityText(text);

  bool matchesText(String value) {
    return normalizedText == normalizeTaskIdentityText(value);
  }

  factory NoteTaskIdentity.fromMap(Map<String, dynamic> data) {
    return NoteTaskIdentity(
      id: data['id'] as String? ?? '',
      lineIndex: data['lineIndex'] as int? ?? -1,
      text: data['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'lineIndex': lineIndex, 'text': text};
  }

  NoteTaskIdentity copyWith({String? id, int? lineIndex, String? text}) {
    return NoteTaskIdentity(
      id: id ?? this.id,
      lineIndex: lineIndex ?? this.lineIndex,
      text: text ?? this.text,
    );
  }
}

String normalizeTaskIdentityText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
