class NoteTask {
  const NoteTask({
    this.id,
    required this.lineIndex,
    required this.text,
    required this.isCompleted,
  });

  final String? id;
  final int lineIndex;
  final String text;
  final bool isCompleted;

  NoteTask copyWith({
    String? id,
    int? lineIndex,
    String? text,
    bool? isCompleted,
  }) {
    return NoteTask(
      id: id ?? this.id,
      lineIndex: lineIndex ?? this.lineIndex,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
