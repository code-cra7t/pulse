class NoteTask {
  const NoteTask({
    required this.lineIndex,
    required this.text,
    required this.isCompleted,
  });

  final int lineIndex;
  final String text;
  final bool isCompleted;
}
