import '../../../core/models/priority_level.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../models/ai_gateway.dart';
import '../models/ask_jotcue.dart';

class AiToolProposalAdapter {
  const AiToolProposalAdapter();

  static const List<Map<String, Object?>> allowedTools = [
    {
      'name': 'task.set_completion',
      'description':
          'Preview marking one existing task complete or incomplete.',
      'arguments': {'taskId': 'string', 'completed': 'boolean'},
    },
    {
      'name': 'task.set_priority',
      'description': 'Preview changing priority for one existing task.',
      'arguments': {
        'taskId': 'string',
        'priority': 'none|low|medium|high|critical',
      },
    },
    {
      'name': 'schedule.move_block',
      'description':
          'Preview moving one existing accepted JotCue schedule block. The local app revalidates calendar and availability before execution.',
      'arguments': {'blockId': 'string', 'startsAt': 'ISO-8601 datetime'},
    },
  ];

  AskJotCueActionProposal? adapt(
    AiGatewayToolCall call,
    AskJotCueContext context,
  ) {
    return switch (call.name) {
      'task.set_completion' => _completion(call.arguments, context),
      'task.set_priority' => _priority(call.arguments, context),
      'schedule.move_block' => _move(call.arguments, context),
      _ => null,
    };
  }

  AskJotCueActionProposal? _completion(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final taskId = args['taskId'];
    final completed = args['completed'];
    if (taskId is! String || completed is! bool) return null;
    final task = _task(taskId, context.tasks);
    if (task == null || task.isCompleted == completed) return null;
    return AskJotCueActionProposal(
      id: 'completion:${task.id}:$completed',
      kind: AskJotCueActionKind.taskCompletion,
      userId: task.userId,
      taskId: task.id,
      taskTitle: task.title,
      sourceNoteId: task.sourceNoteId,
      targetCompletion: completed,
      previewTitle: completed ? 'Mark complete' : 'Reopen task',
      previewText: completed
          ? 'Mark "${task.title}" complete in its source Note.'
          : 'Mark "${task.title}" incomplete in its source Note.',
    );
  }

  AskJotCueActionProposal? _priority(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final taskId = args['taskId'];
    final priorityName = args['priority'];
    if (taskId is! String || priorityName is! String) return null;
    final task = _task(taskId, context.tasks);
    final priority = _priorityFromName(priorityName);
    if (task == null || priority == null || task.priority == priority) {
      return null;
    }
    return AskJotCueActionProposal(
      id: 'priority:${task.id}:${priority.name}',
      kind: AskJotCueActionKind.taskPriority,
      userId: task.userId,
      taskId: task.id,
      taskTitle: task.title,
      sourceNoteId: task.sourceNoteId,
      targetPriority: priority,
      previewTitle: 'Change priority',
      previewText: 'Set "${task.title}" to ${priority.name} priority.',
    );
  }

  AskJotCueActionProposal? _move(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final blockId = args['blockId'];
    final startsAtRaw = args['startsAt'];
    if (blockId is! String || startsAtRaw is! String) return null;
    final startsAt = DateTime.tryParse(startsAtRaw)?.toLocal();
    final block = _block(blockId, context.blocks);
    if (startsAt == null ||
        block == null ||
        block.status != ScheduleBlockStatus.scheduled ||
        !startsAt.isAfter(context.now)) {
      return null;
    }
    final task = _task(block.taskId, context.tasks);
    if (task == null) return null;
    final duration = block.endsAt.difference(block.startsAt);
    if (duration <= Duration.zero) return null;
    final endsAt = startsAt.add(duration);
    return AskJotCueActionProposal(
      id: 'move:${block.id}:${startsAt.toIso8601String()}',
      kind: AskJotCueActionKind.scheduleMove,
      userId: task.userId,
      taskId: task.id,
      taskTitle: task.title,
      blockId: block.id,
      fromStartsAt: block.startsAt,
      fromEndsAt: block.endsAt,
      toStartsAt: startsAt,
      toEndsAt: endsAt,
      previewTitle: 'Move scheduled work',
      previewText:
          'Move "${task.title}" from ${_format(block.startsAt)} to ${_format(startsAt)}.',
    );
  }
}

Task? _task(String id, List<Task> tasks) {
  for (final task in tasks) {
    if (task.id == id) return task;
  }
  return null;
}

ScheduleBlock? _block(String id, List<ScheduleBlock> blocks) {
  for (final block in blocks) {
    if (block.id == id) return block;
  }
  return null;
}

PriorityLevel? _priorityFromName(String value) {
  final normalized = value.trim().toLowerCase();
  for (final priority in PriorityLevel.values) {
    if (priority.name == normalized) return priority;
  }
  return null;
}

String _format(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
