import '../models/note_task.dart';
import '../../reminders/data/smart_reminder_parser.dart';
import '../../reminders/models/parsed_reminder.dart';

class TaskParser {
  static final RegExp _completedTaskPattern = RegExp(
    r'^(\s*)-\s+done:\s+(.*)$',
    caseSensitive: false,
  );
  static final RegExp _bulletTaskPattern = RegExp(r'^(\s*)-\s+(.*)$');
  static final RegExp _legacyCheckboxTaskPattern = RegExp(
    r'^(\s*)- \[([ xX])\]\s?(.*)$',
  );

  static List<NoteTask> extractTasks(String content) {
    final lines = content.split('\n');
    final tasks = <NoteTask>[];

    for (var index = 0; index < lines.length; index++) {
      final completedMatch = _completedTaskPattern.firstMatch(lines[index]);
      final completedText = (completedMatch?.group(2) ?? '').trim();
      if (completedMatch != null && completedText.isNotEmpty) {
        tasks.add(
          NoteTask(
            lineIndex: index,
            text: completedText,
            isCompleted: true,
          ),
        );
        continue;
      }

      final bulletMatch = _bulletTaskPattern.firstMatch(lines[index]);
      final text = (bulletMatch?.group(2) ?? '').trim();
      if (bulletMatch != null && text.isNotEmpty) {
        tasks.add(
          NoteTask(
            lineIndex: index,
            text: text,
            isCompleted: false,
          ),
        );
        continue;
      }

      final legacyMatch = _legacyCheckboxTaskPattern.firstMatch(lines[index]);
      final legacyText = (legacyMatch?.group(3) ?? '').trim();
      if (legacyMatch == null || legacyText.isEmpty) {
        continue;
      }

      tasks.add(
        NoteTask(
          lineIndex: index,
          text: legacyText,
          isCompleted: (legacyMatch.group(2) ?? '').toLowerCase() == 'x',
        ),
      );
    }

    return tasks;
  }

  static String toggleTask(String content, int lineIndex) {
    final currentTask = extractTasks(content).where((task) => task.lineIndex == lineIndex);
    if (currentTask.isEmpty) {
      return content;
    }

    return setTaskCompletion(content, lineIndex, !currentTask.first.isCompleted);
  }

  static String setTaskCompletion(
    String content,
    int lineIndex,
    bool isCompleted,
  ) {
    final lines = content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return content;
    }

    final checkboxMatch = _legacyCheckboxTaskPattern.firstMatch(lines[lineIndex]);
    if (checkboxMatch != null) {
      final indent = checkboxMatch.group(1) ?? '';
      final taskText = checkboxMatch.group(3) ?? '';
      lines[lineIndex] = isCompleted ? '$indent- done: $taskText' : '$indent- $taskText';
      return lines.join('\n');
    }

    final completedMatch = _completedTaskPattern.firstMatch(lines[lineIndex]);
    final completedText = (completedMatch?.group(2) ?? '').trim();
    if (completedMatch != null && completedText.isNotEmpty) {
      final indent = completedMatch.group(1) ?? '';
      lines[lineIndex] = isCompleted ? '$indent- done: $completedText' : '$indent- $completedText';
      return lines.join('\n');
    }

    final bulletMatch = _bulletTaskPattern.firstMatch(lines[lineIndex]);
    final taskText = (bulletMatch?.group(2) ?? '').trim();
    if (bulletMatch == null || taskText.isEmpty) {
      return content;
    }

    final indent = bulletMatch.group(1) ?? '';
    lines[lineIndex] = isCompleted ? '$indent- done: $taskText' : '$indent- $taskText';
    return lines.join('\n');
  }

  static String deleteTask(String content, int lineIndex) {
    final lines = content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return content;
    }

    lines.removeAt(lineIndex);
    return lines.join('\n');
  }

  static String migrateLegacyTasks(String content) {
    final lines = content.split('\n');

    for (var index = 0; index < lines.length; index++) {
      final legacyMatch = _legacyCheckboxTaskPattern.firstMatch(lines[index]);
      final taskText = (legacyMatch?.group(3) ?? '').trim();
      if (legacyMatch == null || taskText.isEmpty) {
        continue;
      }

      final indent = legacyMatch.group(1) ?? '';
      final isCompleted = (legacyMatch.group(2) ?? '').toLowerCase() == 'x';
      lines[index] = isCompleted ? '$indent- done: $taskText' : '$indent- $taskText';
    }

    return lines.join('\n');
  }

  static String normalizeTaskContent(String content) {
    return migrateLegacyTasks(content);
  }

  static List<TaskReminderSuggestion> extractTaskReminderSuggestions(
    String content,
    SmartReminderParser reminderParser,
  ) {
    return extractTasks(content)
        .map((task) {
          final reminder = reminderParser.parse(task.text);
          if (reminder == null) {
            return null;
          }

          return TaskReminderSuggestion(
            task: task,
            reminder: reminder,
          );
        })
        .whereType<TaskReminderSuggestion>()
        .toList();
  }

  static List<String> extractPlainTextLines(String content) {
    return content
        .split('\n')
        .where(
          (line) =>
              !_completedTaskPattern.hasMatch(line) &&
              !_legacyCheckboxTaskPattern.hasMatch(line) &&
              !_bulletTaskPattern.hasMatch(line),
        )
        .where((line) => line.trim().isNotEmpty)
        .toList();
  }
}

class TaskReminderSuggestion {
  const TaskReminderSuggestion({
    required this.task,
    required this.reminder,
  });

  final NoteTask task;
  final ParsedReminder reminder;
}
