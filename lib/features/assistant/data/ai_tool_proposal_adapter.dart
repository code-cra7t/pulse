import '../../../core/models/priority_level.dart';
import '../../capture/data/natural_language_capture_parser.dart';
import '../../capture/models/capture_draft.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_metadata_update.dart';
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
      'name': 'task.set_deadline',
      'description':
          'Preview setting or clearing the deadline for one existing task.',
      'arguments': {
        'taskId': 'string',
        'dueAt': 'ISO-8601 date or datetime',
        'clear': 'boolean',
      },
    },
    {
      'name': 'task.assign_project',
      'description':
          'Preview assigning one existing task to one existing project, or clearing its project.',
      'arguments': {
        'taskId': 'string',
        'projectId': 'string',
        'clear': 'boolean',
      },
    },
    {
      'name': 'task.set_estimate',
      'description':
          'Preview setting or clearing the positive estimated minutes for one existing task.',
      'arguments': {
        'taskId': 'string',
        'minutes': 'integer',
        'clear': 'boolean',
      },
    },
    {
      'name': 'task.set_dependencies',
      'description':
          'Preview replacing the prerequisite task IDs for one existing task. IDs must refer to current local tasks.',
      'arguments': {'taskId': 'string', 'dependsOnTaskIds': 'string[]'},
    },
    {
      'name': 'task.set_waiting_for',
      'description':
          'Preview setting or clearing short Waiting for text for one existing task.',
      'arguments': {
        'taskId': 'string',
        'waitingFor': 'string',
        'clear': 'boolean',
      },
    },
    {
      'name': 'schedule.move_block',
      'description':
          'Preview moving one existing accepted JotCue schedule block. The local app revalidates calendar and availability before execution.',
      'arguments': {'blockId': 'string', 'startsAt': 'ISO-8601 datetime'},
    },
    {
      'name': 'capture.create',
      'description':
          'Preview a Task or Project capture. The local app parses the supplied text conservatively and requires user approval before creation.',
      'arguments': {'text': 'string'},
    },
    {
      'name': 'note.save',
      'description':
          'Preview saving explicit user-provided text as a captured Note.',
      'arguments': {'text': 'string'},
    },
  ];

  AskJotCueActionProposal? adapt(
    AiGatewayToolCall call,
    AskJotCueContext context,
  ) {
    return switch (call.name) {
      'task.set_completion' => _completion(call.arguments, context),
      'task.set_priority' => _priority(call.arguments, context),
      'task.set_deadline' => _deadline(call.arguments, context),
      'task.assign_project' => _project(call.arguments, context),
      'task.set_estimate' => _estimate(call.arguments, context),
      'task.set_dependencies' => _dependencies(call.arguments, context),
      'task.set_waiting_for' => _waitingFor(call.arguments, context),
      'schedule.move_block' => _move(call.arguments, context),
      'capture.create' => _capture(call.arguments, context),
      'note.save' => _note(call.arguments, context),
      _ => null,
    };
  }

  AskJotCueActionProposal? _capture(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final userId = context.userId?.trim();
    final text = args['text'];
    if (userId == null || userId.isEmpty || text is! String) return null;
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.length > 2000) return null;
    final parser = const NaturalLanguageCaptureParser();
    final draft =
        parser.parseCommand(normalized, now: context.now) ??
        parser.parse(normalized, now: context.now);
    if (draft == null) return null;
    return AskJotCueActionProposal(
      id: 'capture:${draft.kind.name}:${draft.rawText.hashCode}',
      kind: AskJotCueActionKind.structuredCapture,
      userId: userId,
      previewTitle: _captureTitle(draft),
      previewText: _captureText(draft),
      captureDraft: draft,
    );
  }

  AskJotCueActionProposal? _note(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final userId = context.userId?.trim();
    final text = args['text'];
    if (userId == null || userId.isEmpty || text is! String) return null;
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.length > 4000) return null;
    return AskJotCueActionProposal(
      id: 'note:${normalized.hashCode}',
      kind: AskJotCueActionKind.noteCreate,
      userId: userId,
      previewTitle: 'Save note',
      previewText: 'Save this as a captured note:\n“$normalized”',
      noteText: normalized,
    );
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

  AskJotCueActionProposal? _deadline(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final task = _taskArg(args, context);
    if (task == null) return null;
    final clear = args['clear'] == true;
    if (clear) {
      if (task.dueAt == null) return null;
      return _metadataProposal(
        task,
        idSuffix: 'deadline:clear',
        update: const TaskMetadataUpdate(clearDueAt: true),
        previewTitle: 'Clear deadline',
        previewText: 'Remove the deadline from "${task.title}".',
      );
    }
    final raw = args['dueAt'];
    if (raw is! String) return null;
    final dueAt = _parseToolDueAt(raw);
    if (dueAt == null || _sameDate(task.dueAt, dueAt)) return null;
    return _metadataProposal(
      task,
      idSuffix: 'deadline:${dueAt.millisecondsSinceEpoch}',
      update: TaskMetadataUpdate(dueAt: dueAt),
      previewTitle: 'Set deadline',
      previewText: 'Set "${task.title}" due ${_formatDate(dueAt)}.',
    );
  }

  AskJotCueActionProposal? _project(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final task = _taskArg(args, context);
    if (task == null) return null;
    final clear = args['clear'] == true;
    if (clear) {
      if (task.projectId == null) return null;
      return _metadataProposal(
        task,
        idSuffix: 'project:clear',
        update: const TaskMetadataUpdate(clearProjectId: true),
        previewTitle: 'Remove from project',
        previewText: 'Remove "${task.title}" from its current Project.',
      );
    }
    final projectId = args['projectId'];
    if (projectId is! String || projectId.trim().isEmpty) return null;
    final project = context.projects
        .where((item) => item.id == projectId)
        .toList();
    if (project.length != 1 || task.projectId == projectId) return null;
    return _metadataProposal(
      task,
      idSuffix: 'project:$projectId',
      update: TaskMetadataUpdate(projectId: projectId),
      previewTitle: 'Assign to project',
      previewText: 'Assign "${task.title}" to ${project.single.name}.',
    );
  }

  AskJotCueActionProposal? _estimate(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final task = _taskArg(args, context);
    if (task == null) return null;
    final clear = args['clear'] == true;
    if (clear) {
      if (task.estimatedMinutes == null) return null;
      return _metadataProposal(
        task,
        idSuffix: 'estimate:clear',
        update: const TaskMetadataUpdate(clearEstimatedMinutes: true),
        previewTitle: 'Clear effort estimate',
        previewText: 'Remove the effort estimate from "${task.title}".',
      );
    }
    final raw = args['minutes'];
    if (raw is! int ||
        raw <= 0 ||
        raw > 10080 ||
        task.estimatedMinutes == raw) {
      return null;
    }
    return _metadataProposal(
      task,
      idSuffix: 'estimate:$raw',
      update: TaskMetadataUpdate(estimatedMinutes: raw),
      previewTitle: 'Set effort estimate',
      previewText: 'Set "${task.title}" to $raw estimated minutes.',
    );
  }

  AskJotCueActionProposal? _dependencies(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final task = _taskArg(args, context);
    final raw = args['dependsOnTaskIds'];
    if (task == null || raw is! List) return null;
    final known = context.tasks.map((item) => item.id).toSet();
    final dependencies = <String>[];
    final seen = <String>{};
    for (final value in raw) {
      if (value is! String) return null;
      final id = value.trim();
      if (id.isEmpty || id == task.id || !known.contains(id)) return null;
      if (seen.add(id)) dependencies.add(id);
    }
    if (_sameStringList(task.dependsOnTaskIds, dependencies)) return null;
    return _metadataProposal(
      task,
      idSuffix: 'dependencies:${dependencies.join(',')}',
      update: TaskMetadataUpdate(dependsOnTaskIds: dependencies),
      previewTitle: 'Update prerequisites',
      previewText:
          'Replace prerequisites for "${task.title}" with ${dependencies.length} ${dependencies.length == 1 ? 'task' : 'tasks'}.',
    );
  }

  AskJotCueActionProposal? _waitingFor(
    Map<String, Object?> args,
    AskJotCueContext context,
  ) {
    final task = _taskArg(args, context);
    if (task == null) return null;
    final clear = args['clear'] == true;
    if (clear) {
      if (task.waitingFor == null || task.waitingFor!.trim().isEmpty) {
        return null;
      }
      return _metadataProposal(
        task,
        idSuffix: 'waiting:clear',
        update: const TaskMetadataUpdate(clearWaitingFor: true),
        previewTitle: 'Clear waiting for',
        previewText: 'Clear Waiting for on "${task.title}".',
      );
    }
    final waitingFor = args['waitingFor'];
    if (waitingFor is! String) return null;
    final normalized = waitingFor.trim();
    if (normalized.isEmpty || normalized.length > 200) return null;
    if ((task.waitingFor ?? '').trim().toLowerCase() ==
        normalized.toLowerCase()) {
      return null;
    }
    return _metadataProposal(
      task,
      idSuffix: 'waiting:${normalized.hashCode}',
      update: TaskMetadataUpdate(waitingFor: normalized),
      previewTitle: 'Set waiting for',
      previewText: 'Mark "${task.title}" as waiting for $normalized.',
    );
  }

  Task? _taskArg(Map<String, Object?> args, AskJotCueContext context) {
    final taskId = args['taskId'];
    if (taskId is! String) return null;
    return _task(taskId, context.tasks);
  }

  AskJotCueActionProposal _metadataProposal(
    Task task, {
    required String idSuffix,
    required TaskMetadataUpdate update,
    required String previewTitle,
    required String previewText,
  }) {
    return AskJotCueActionProposal(
      id: 'metadata:${task.id}:$idSuffix',
      kind: AskJotCueActionKind.taskMetadata,
      userId: task.userId,
      taskId: task.id,
      taskTitle: task.title,
      sourceNoteId: task.sourceNoteId,
      metadataUpdate: update,
      previewTitle: previewTitle,
      previewText: previewText,
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

String _captureTitle(CaptureDraft draft) {
  return switch (draft.kind) {
    CaptureDraftKind.project =>
      draft.tasks.isEmpty
          ? 'Create project'
          : 'Create project + ${draft.tasks.length} ${draft.tasks.length == 1 ? 'task' : 'tasks'}',
    CaptureDraftKind.task => 'Create task',
    CaptureDraftKind.taskList => 'Create ${draft.tasks.length} tasks',
  };
}

String _captureText(CaptureDraft draft) {
  final lines = <String>[];
  if (draft.createsProject) {
    lines.add('Project: ${draft.projectName ?? 'New project'}');
  }
  for (final task in draft.tasks) {
    lines.add('• $task');
  }
  if (draft.deadline != null) {
    final value = draft.deadline!;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    lines.add('Deadline: ${value.year}-$month-$day');
  }
  return lines.join('\n');
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

DateTime? _parseToolDueAt(String value) {
  final normalized = value.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day, 23, 59);
  }
  return DateTime.tryParse(normalized)?.toLocal();
}

bool _sameDate(DateTime? a, DateTime b) {
  return a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _format(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
