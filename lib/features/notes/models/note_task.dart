class NoteTask {
  const NoteTask({
    required this.lineIndex,
    required this.text,
    required this.isCompleted,
  });

  final int lineIndex;
  final String text;
  final bool isCompleted;

  NoteTask copyWith({
    int? lineIndex,
    String? text,
    bool? isCompleted,
  }) {
    return NoteTask(
      lineIndex: lineIndex ?? this.lineIndex,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
