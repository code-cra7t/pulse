import '../models/note_task.dart';

class TaskParser {
  static final RegExp _taskPattern = RegExp(r'^(\s*)- \[([ xX])\]\s?(.*)$');

  static List<NoteTask> extractTasks(String content) {
    final lines = content.split('\n');
    final tasks = <NoteTask>[];

    for (var index = 0; index < lines.length; index++) {
      final match = _taskPattern.firstMatch(lines[index]);
      if (match == null) {
        continue;
      }

      tasks.add(
        NoteTask(
          lineIndex: index,
          text: match.group(3) ?? '',
          isCompleted: (match.group(2) ?? '').toLowerCase() == 'x',
        ),
      );
    }

    return tasks;
  }

  static String toggleTask(String content, int lineIndex) {
    final lines = content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return content;
    }

    final match = _taskPattern.firstMatch(lines[lineIndex]);
    if (match == null) {
      return content;
    }

    final indent = match.group(1) ?? '';
    final marker = (match.group(2) ?? '').toLowerCase() == 'x' ? ' ' : 'x';
    final taskText = match.group(3) ?? '';

    lines[lineIndex] = '$indent- [$marker] $taskText';
    return lines.join('\n');
  }

  static List<String> extractPlainTextLines(String content) {
    return content
        .split('\n')
        .where((line) => !_taskPattern.hasMatch(line))
        .where((line) => line.trim().isNotEmpty)
        .toList();
  }
}
