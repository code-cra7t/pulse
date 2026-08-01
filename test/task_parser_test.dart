import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/notes/utils/task_parser.dart';
import 'package:pulse/features/reminders/data/smart_reminder_parser.dart';

void main() {
  test('parses current task text and ties reminder suggestion to its line', () {
    const content = '- Send report tomorrow at 5\nRegular note text';
    final suggestions = TaskParser.extractTaskReminderSuggestions(
      content,
      SmartReminderParser(),
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.task.lineIndex, 0);
    expect(suggestions.single.task.text, 'Send report tomorrow at 5');
    expect(suggestions.single.reminder.matchedPhrase, 'tomorrow at 5');
  });

  test('deleting a task line removes it from subsequent parsing', () {
    const content = 'Intro\n- First task\n- done: Second task\nTail';
    final updated = TaskParser.deleteTask(content, 1);
    final tasks = TaskParser.extractTasks(updated);

    expect(updated, 'Intro\n- done: Second task\nTail');
    expect(tasks, hasLength(1));
    expect(tasks.single.text, 'Second task');
    expect(tasks.single.isCompleted, isTrue);
    expect(tasks.single.lineIndex, 1);
  });

  test('legacy checkbox tasks keep their completion state', () {
    const content = '- [x] Existing task\n- [ ] Active task';
    final tasks = TaskParser.extractTasks(content);

    expect(tasks, hasLength(2));
    expect(tasks.first.text, 'Existing task');
    expect(tasks.first.isCompleted, isTrue);
    expect(tasks.last.text, 'Active task');
    expect(tasks.last.isCompleted, isFalse);
  });
}
