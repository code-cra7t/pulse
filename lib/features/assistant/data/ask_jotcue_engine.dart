import '../../../core/models/priority_level.dart';
import '../../capture/data/natural_language_capture_parser.dart';
import '../../capture/models/capture_draft.dart';
import '../../projects/models/project.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_metadata_update.dart';
import '../models/ask_jotcue.dart';

/// Deterministic assistant over JotCue's existing planning state.
///
/// This engine never mutates data. It may prepare a narrowly typed action
/// preview; execution is handled separately behind automation permissions.
class AskJotCueEngine {
  const AskJotCueEngine();

  AskJotCueAnswer answer({
    required String query,
    required AskJotCueContext context,
  }) {
    final action = _actionAnswer(query, context);
    if (action != null) {
      return action;
    }

    final intent = classify(query);
    return switch (intent) {
      AskJotCueIntent.action => _unknown(),
      AskJotCueIntent.focusNow => _focus(context),
      AskJotCueIntent.dueSoon => _dueSoon(context),
      AskJotCueIntent.overdue => _overdue(context),
      AskJotCueIntent.capacityToday => _capacity(context),
      AskJotCueIntent.scheduleToday => _schedule(context),
      AskJotCueIntent.nextBlock => _nextBlock(context),
      AskJotCueIntent.projects => _projects(context),
      AskJotCueIntent.needsAttention => _attention(context),
      AskJotCueIntent.help => _help(),
      AskJotCueIntent.unknown => _unknown(),
    };
  }

  AskJotCueIntent classify(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty ||
        _containsAny(normalized, const [
          'help',
          'what can you do',
          'what can i ask',
          'what can you change',
          'how can you help',
        ])) {
      return AskJotCueIntent.help;
    }

    if (_containsAny(normalized, const [
      'what should i do now',
      'what should i work on',
      'what should i focus',
      'what matters most',
      'my priorities',
      'priority right now',
      'focus now',
    ])) {
      return AskJotCueIntent.focusNow;
    }

    if (_containsAny(normalized, const [
      'overdue',
      'behind',
      'late task',
      'what am i late',
    ])) {
      return AskJotCueIntent.overdue;
    }

    if (_containsAny(normalized, const [
      'free time',
      'how much time',
      'capacity today',
      'available today',
      'time do i have',
    ])) {
      return AskJotCueIntent.capacityToday;
    }

    if (_containsAny(normalized, const [
      'what is next',
      "what's next",
      'next block',
      'next scheduled',
      'up next',
    ])) {
      return AskJotCueIntent.nextBlock;
    }

    if (_containsAny(normalized, const [
      'schedule today',
      "today's schedule",
      'today schedule',
      'planned today',
      'what is planned',
      "what's planned",
    ])) {
      return AskJotCueIntent.scheduleToday;
    }

    if (_containsAny(normalized, const [
      'due soon',
      'deadline',
      'due next',
      'coming up',
      'due this week',
    ])) {
      return AskJotCueIntent.dueSoon;
    }

    if (_containsAny(normalized, const [
      'needs attention',
      'need attention',
      'what am i forgetting',
      'what needs review',
      'problems with my plan',
      'schedule problems',
    ])) {
      return AskJotCueIntent.needsAttention;
    }

    if (_containsAny(normalized, const ['project', 'projects'])) {
      return AskJotCueIntent.projects;
    }

    return AskJotCueIntent.unknown;
  }

  AskJotCueAnswer? _actionAnswer(String query, AskJotCueContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final completion = _completionAction(trimmed, context);
    if (completion != null) return completion;

    final priority = _priorityAction(trimmed, context);
    if (priority != null) return priority;

    final planning = _planningMetadataAction(trimmed, context);
    if (planning != null) return planning;

    final move = _scheduleMoveAction(trimmed, context);
    if (move != null) return move;

    final capture = _captureAction(trimmed, context);
    if (capture != null) return capture;

    return null;
  }

  AskJotCueAnswer? _completionAction(String query, AskJotCueContext context) {
    final donePatterns = <RegExp>[
      RegExp(
        r'^mark\s+(.+?)\s+(?:done|complete|completed)$',
        caseSensitive: false,
      ),
      RegExp(r'^complete\s+(.+)$', caseSensitive: false),
    ];
    final reopenPatterns = <RegExp>[
      RegExp(
        r'^mark\s+(.+?)\s+(?:incomplete|open|not done)$',
        caseSensitive: false,
      ),
      RegExp(r'^reopen\s+(.+)$', caseSensitive: false),
    ];

    for (final pattern in donePatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      return _taskCompletionProposal(
        context,
        candidate: match.group(1) ?? '',
        target: true,
      );
    }
    for (final pattern in reopenPatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      return _taskCompletionProposal(
        context,
        candidate: match.group(1) ?? '',
        target: false,
      );
    }
    return null;
  }

  AskJotCueAnswer _taskCompletionProposal(
    AskJotCueContext context, {
    required String candidate,
    required bool target,
  }) {
    final resolution = _resolveTask(candidate, context.tasks);
    if (resolution.task == null) {
      return _taskResolutionAnswer(resolution, candidate);
    }
    final task = resolution.task!;
    if (task.isCompleted == target) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: target ? 'Already complete' : 'Already open',
        text: target
            ? '"${task.title}" is already complete.'
            : '"${task.title}" is already open.',
      );
    }

    final verb = target ? 'Mark complete' : 'Reopen task';
    final proposal = AskJotCueActionProposal(
      id: 'completion:${task.id}:$target',
      kind: AskJotCueActionKind.taskCompletion,
      userId: task.userId,
      taskId: task.id,
      taskTitle: task.title,
      sourceNoteId: task.sourceNoteId,
      targetCompletion: target,
      previewTitle: verb,
      previewText: target
          ? 'Mark "${task.title}" complete in its source Note.'
          : 'Mark "${task.title}" incomplete in its source Note.',
    );
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Action preview',
      text:
          'I understand this as a Task completion change. Nothing has changed yet.',
      actionProposal: proposal,
    );
  }

  AskJotCueAnswer? _priorityAction(String query, AskJotCueContext context) {
    final patterns = <RegExp>[
      RegExp(
        r'^(?:set|make)\s+(.+?)\s+priority\s+(?:to\s+)?(critical|high|medium|low|none)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^set\s+priority\s+(?:of|for)\s+(.+?)\s+to\s+(critical|high|medium|low|none)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^make\s+(.+?)\s+(critical|high|medium|low)\s+priority$',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final priority = _priorityFromWord(match.group(2));
      final task = resolution.task!;
      if (task.priority == priority) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text:
              '"${task.title}" is already ${_priorityName(priority)} priority.',
        );
      }
      final proposal = AskJotCueActionProposal(
        id: 'priority:${task.id}:${priority.name}',
        kind: AskJotCueActionKind.taskPriority,
        userId: task.userId,
        taskId: task.id,
        taskTitle: task.title,
        sourceNoteId: task.sourceNoteId,
        targetPriority: priority,
        previewTitle: 'Change priority',
        previewText:
            'Set "${task.title}" from ${_priorityName(task.priority)} to ${_priorityName(priority)} priority.',
      );
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Action preview',
        text:
            'I understand this as a Task planning change. Nothing has changed yet.',
        actionProposal: proposal,
      );
    }
    return null;
  }

  AskJotCueAnswer? _planningMetadataAction(
    String query,
    AskJotCueContext context,
  ) {
    return _deadlineAction(query, context) ??
        _projectAction(query, context) ??
        _estimateAction(query, context) ??
        _dependencyAction(query, context) ??
        _waitingForAction(query, context);
  }

  AskJotCueAnswer? _deadlineAction(String query, AskJotCueContext context) {
    final clearPatterns = <RegExp>[
      RegExp(
        r'^(?:clear|remove)\s+(?:the\s+)?deadline\s+(?:for|from)\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:clear|remove)\s+(.+?)\s+(?:due date|deadline)$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in clearPatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final task = resolution.task!;
      if (task.dueAt == null) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" does not have a deadline.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'deadline:clear',
        update: const TaskMetadataUpdate(clearDueAt: true),
        previewTitle: 'Clear deadline',
        previewText: 'Remove the deadline from "${task.title}".',
      );
    }

    final setPatterns = <RegExp>[
      RegExp(
        r'^(?:set|make)\s+(.+?)\s+(?:due|deadline)\s+(?:to\s+|for\s+|on\s+)?(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^set\s+(?:the\s+)?deadline\s+(?:of|for)\s+(.+?)\s+(?:to|for|on)\s+(.+)$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in setPatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final dueAt = _parsePlanningDueDate(match.group(2) ?? '', context.now);
      if (dueAt == null) {
        return const AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'I need a clearer deadline',
          text:
              'Use a date like “tomorrow”, “Sep 30”, or “2026-09-30”. Nothing has changed.',
        );
      }
      final task = resolution.task!;
      if (_sameCalendarDate(task.dueAt, dueAt)) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" is already due ${_date(dueAt)}.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'deadline:${dueAt.millisecondsSinceEpoch}',
        update: TaskMetadataUpdate(dueAt: dueAt),
        previewTitle: 'Set deadline',
        previewText: 'Set "${task.title}" due ${_date(dueAt)}.',
      );
    }
    return null;
  }

  AskJotCueAnswer? _projectAction(String query, AskJotCueContext context) {
    final clearPatterns = <RegExp>[
      RegExp(
        r'^(?:remove|unassign)\s+(.+?)\s+from\s+(?:its\s+)?project$',
        caseSensitive: false,
      ),
      RegExp(
        r'^clear\s+(?:the\s+)?project\s+(?:for|from)\s+(.+)$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in clearPatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final task = resolution.task!;
      if (task.projectId == null) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" is not assigned to a Project.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'project:clear',
        update: const TaskMetadataUpdate(clearProjectId: true),
        previewTitle: 'Remove from project',
        previewText: 'Remove "${task.title}" from its current Project.',
      );
    }

    final patterns = <RegExp>[
      RegExp(
        r'^(?:assign|add)\s+(.+?)\s+to\s+(?:project\s+)(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^put\s+(.+?)\s+under\s+(?:project\s+)?(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^set\s+(?:the\s+)?project\s+(?:for|of)\s+(.+?)\s+to\s+(.+)$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final taskResolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (taskResolution.task == null) {
        return _taskResolutionAnswer(taskResolution, match.group(1) ?? '');
      }
      final projectResolution = _resolveProject(
        match.group(2) ?? '',
        context.projects,
      );
      if (projectResolution.project == null) {
        return _projectResolutionAnswer(
          projectResolution,
          match.group(2) ?? '',
        );
      }
      final task = taskResolution.task!;
      final project = projectResolution.project!;
      if (task.projectId == project.id) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" is already in ${project.name}.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'project:${project.id}',
        update: TaskMetadataUpdate(projectId: project.id),
        previewTitle: 'Assign to project',
        previewText: 'Assign "${task.title}" to ${project.name}.',
      );
    }
    return null;
  }

  AskJotCueAnswer? _estimateAction(String query, AskJotCueContext context) {
    final clearPatterns = <RegExp>[
      RegExp(
        r'^(?:clear|remove)\s+(?:the\s+)?(?:estimate|effort estimate)\s+(?:for|from)\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:clear|remove)\s+(.+?)\s+(?:estimate|effort estimate)$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in clearPatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final task = resolution.task!;
      if (task.estimatedMinutes == null) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" does not have an effort estimate.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'estimate:clear',
        update: const TaskMetadataUpdate(clearEstimatedMinutes: true),
        previewTitle: 'Clear effort estimate',
        previewText: 'Remove the effort estimate from "${task.title}".',
      );
    }

    final patterns = <RegExp>[
      RegExp(
        r'^set\s+(.+?)\s+(?:estimate|effort)\s+(?:to\s+)?(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'^estimate\s+(.+?)\s+(?:at|as)\s+(.+)$', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final minutes = _parseEffortMinutes(match.group(2) ?? '');
      if (minutes == null) {
        return const AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'I need a clearer estimate',
          text:
              'Use an effort like “45 minutes”, “90 mins”, or “2 hours”. Nothing has changed.',
        );
      }
      final task = resolution.task!;
      if (task.estimatedMinutes == minutes) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text:
              '"${task.title}" is already estimated at ${_formatMinutes(minutes)}.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'estimate:$minutes',
        update: TaskMetadataUpdate(estimatedMinutes: minutes),
        previewTitle: 'Set effort estimate',
        previewText:
            'Set "${task.title}" to ${_formatMinutes(minutes)} estimated effort.',
      );
    }
    return null;
  }

  AskJotCueAnswer? _dependencyAction(String query, AskJotCueContext context) {
    final patterns = <(RegExp, bool, int, int)>[
      (
        RegExp(r'^make\s+(.+?)\s+depend\s+on\s+(.+)$', caseSensitive: false),
        true,
        1,
        2,
      ),
      (
        RegExp(
          r'^add\s+(.+?)\s+as\s+(?:a\s+)?prerequisite\s+for\s+(.+)$',
          caseSensitive: false,
        ),
        true,
        2,
        1,
      ),
      (
        RegExp(
          r'^remove\s+(.+?)\s+as\s+(?:a\s+)?prerequisite\s+for\s+(.+)$',
          caseSensitive: false,
        ),
        false,
        2,
        1,
      ),
      (
        RegExp(
          r'^remove\s+(?:dependency\s+)?(.+?)\s+from\s+(.+)$',
          caseSensitive: false,
        ),
        false,
        2,
        1,
      ),
    ];

    for (final entry in patterns) {
      final match = entry.$1.firstMatch(query);
      if (match == null) continue;
      final taskResolution = _resolveTask(
        match.group(entry.$3) ?? '',
        context.tasks,
      );
      if (taskResolution.task == null) {
        return _taskResolutionAnswer(
          taskResolution,
          match.group(entry.$3) ?? '',
        );
      }
      final prerequisiteResolution = _resolveTask(
        match.group(entry.$4) ?? '',
        context.tasks,
      );
      if (prerequisiteResolution.task == null) {
        return _taskResolutionAnswer(
          prerequisiteResolution,
          match.group(entry.$4) ?? '',
        );
      }
      final task = taskResolution.task!;
      final prerequisite = prerequisiteResolution.task!;
      if (task.id == prerequisite.id) {
        return const AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'Invalid dependency',
          text: 'A Task cannot depend on itself. Nothing has changed.',
        );
      }

      final dependencies = <String>[...task.dependsOnTaskIds];
      if (entry.$2) {
        if (dependencies.contains(prerequisite.id)) {
          return AskJotCueAnswer(
            intent: AskJotCueIntent.action,
            title: 'No change needed',
            text: '"${task.title}" already depends on "${prerequisite.title}".',
          );
        }
        dependencies.add(prerequisite.id);
      } else {
        if (!dependencies.remove(prerequisite.id)) {
          return AskJotCueAnswer(
            intent: AskJotCueIntent.action,
            title: 'No change needed',
            text: '"${task.title}" does not depend on "${prerequisite.title}".',
          );
        }
      }

      return _taskMetadataProposal(
        task,
        idSuffix:
            'dependency:${entry.$2 ? 'add' : 'remove'}:${prerequisite.id}',
        update: TaskMetadataUpdate(dependsOnTaskIds: dependencies),
        previewTitle: entry.$2 ? 'Add prerequisite' : 'Remove prerequisite',
        previewText: entry.$2
            ? 'Make "${task.title}" depend on "${prerequisite.title}".'
            : 'Remove "${prerequisite.title}" as a prerequisite for "${task.title}".',
      );
    }
    return null;
  }

  AskJotCueAnswer? _waitingForAction(String query, AskJotCueContext context) {
    final clearPatterns = <RegExp>[
      RegExp(r'^clear\s+waiting\s+for\s+(.+)$', caseSensitive: false),
      RegExp(r'^clear\s+(.+?)\s+waiting\s+for$', caseSensitive: false),
    ];
    for (final pattern in clearPatterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final task = resolution.task!;
      if (task.waitingFor == null || task.waitingFor!.trim().isEmpty) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" is not marked as waiting for anything.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'waiting:clear',
        update: const TaskMetadataUpdate(clearWaitingFor: true),
        previewTitle: 'Clear waiting for',
        previewText: 'Clear Waiting for on "${task.title}".',
      );
    }

    final patterns = <RegExp>[
      RegExp(r'^set\s+(.+?)\s+waiting\s+for\s+(.+)$', caseSensitive: false),
      RegExp(r'^(.+?)\s+is\s+waiting\s+for\s+(.+)$', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final resolution = _resolveTask(match.group(1) ?? '', context.tasks);
      if (resolution.task == null) {
        return _taskResolutionAnswer(resolution, match.group(1) ?? '');
      }
      final waitingFor = (match.group(2) ?? '').trim();
      if (waitingFor.isEmpty || waitingFor.length > 200) {
        return const AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'I need a clearer blocker',
          text:
              'Waiting for must be short, explicit text. Nothing has changed.',
        );
      }
      final task = resolution.task!;
      if (_normalize(task.waitingFor ?? '') == _normalize(waitingFor)) {
        return AskJotCueAnswer(
          intent: AskJotCueIntent.action,
          title: 'No change needed',
          text: '"${task.title}" is already waiting for $waitingFor.',
        );
      }
      return _taskMetadataProposal(
        task,
        idSuffix: 'waiting:${waitingFor.hashCode}',
        update: TaskMetadataUpdate(waitingFor: waitingFor),
        previewTitle: 'Set waiting for',
        previewText: 'Mark "${task.title}" as waiting for $waitingFor.',
      );
    }
    return null;
  }

  AskJotCueAnswer _taskMetadataProposal(
    Task task, {
    required String idSuffix,
    required TaskMetadataUpdate update,
    required String previewTitle,
    required String previewText,
  }) {
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Action preview',
      text:
          'I understand this as a Task planning change. Nothing has changed yet.',
      actionProposal: AskJotCueActionProposal(
        id: 'metadata:${task.id}:$idSuffix',
        kind: AskJotCueActionKind.taskMetadata,
        userId: task.userId,
        taskId: task.id,
        taskTitle: task.title,
        sourceNoteId: task.sourceNoteId,
        metadataUpdate: update,
        previewTitle: previewTitle,
        previewText: previewText,
      ),
    );
  }

  AskJotCueAnswer _projectResolutionAnswer(
    _ProjectResolution resolution,
    String candidate,
  ) {
    if (resolution.ambiguous) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Project name is ambiguous',
        text:
            'More than one Project matches “${candidate.trim()}”. Use the full Project name so JotCue does not guess.',
      );
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Project not found',
      text:
          'I could not find a current Project matching “${candidate.trim()}”. Nothing has changed.',
    );
  }

  AskJotCueAnswer? _scheduleMoveAction(String query, AskJotCueContext context) {
    final pattern = RegExp(
      r'^move\s+(.+?)\s+(?:to\s+)?(today|tomorrow|\d{4}-\d{2}-\d{2})\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(query);
    if (match == null) return null;

    final candidate = match.group(1) ?? '';
    final resolution = _resolveTask(candidate, context.tasks);
    if (resolution.task == null) {
      return _taskResolutionAnswer(resolution, candidate);
    }
    final task = resolution.task!;
    final futureBlocks =
        context.blocks
            .where(
              (block) =>
                  block.taskId == task.id &&
                  block.status == ScheduleBlockStatus.scheduled &&
                  block.endsAt.isAfter(context.now),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (futureBlocks.isEmpty) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Nothing to move',
        text:
            '"${task.title}" does not have a future accepted JotCue schedule block.',
      );
    }
    if (futureBlocks.length > 1) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Choose the block in Plan',
        text:
            '"${task.title}" has more than one future accepted block. Move the specific block from Plan so JotCue does not guess.',
      );
    }

    final date = _parseMoveDate(match.group(2)!, context.now);
    final hourMinute = _parseClock(
      match.group(3)!,
      match.group(4),
      match.group(5),
    );
    if (date == null || hourMinute == null) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'I need a clearer time',
        text:
            'Use a future time like “tomorrow at 15:00” or “2026-09-15 at 3pm”.',
      );
    }
    final targetStart = DateTime(
      date.year,
      date.month,
      date.day,
      hourMinute.$1,
      hourMinute.$2,
    );
    if (!targetStart.isAfter(context.now)) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'That time has passed',
        text: 'Ask JotCue to move the block to a future time.',
      );
    }

    final block = futureBlocks.single;
    if (targetStart == block.startsAt) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'No change needed',
        text:
            '"${task.title}" is already planned for ${_dateTime(targetStart)}.',
      );
    }
    final targetEnd = targetStart.add(block.duration);
    final conflict = context.blocks.any(
      (other) =>
          other.id != block.id &&
          other.occupiesTime &&
          other.startsAt.isBefore(targetEnd) &&
          other.endsAt.isAfter(targetStart),
    );
    if (conflict) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'That time is already occupied',
        text:
            'Another accepted JotCue block overlaps ${_dateTime(targetStart)}. Choose another time or review Plan.',
      );
    }

    final proposal = AskJotCueActionProposal(
      id: 'move:${block.id}:${targetStart.millisecondsSinceEpoch}',
      kind: AskJotCueActionKind.scheduleMove,
      userId: block.userId,
      taskId: task.id,
      taskTitle: task.title,
      blockId: block.id,
      fromStartsAt: block.startsAt,
      fromEndsAt: block.endsAt,
      toStartsAt: targetStart,
      toEndsAt: targetEnd,
      previewTitle: 'Move scheduled block',
      previewText:
          'Move "${task.title}" from ${_dateTime(block.startsAt)} to ${_dateTime(targetStart)}. Duration stays ${_formatMinutes(block.duration.inMinutes)}.',
    );
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Action preview',
      text:
          'I found one accepted JotCue block to move. Nothing has changed yet.',
      actionProposal: proposal,
    );
  }

  AskJotCueAnswer? _captureAction(String query, AskJotCueContext context) {
    final noteText = _explicitNoteText(query);
    final draft = const NaturalLanguageCaptureParser().parseCommand(
      query,
      now: context.now,
    );
    if (noteText == null && draft == null) return null;

    final userId = context.userId?.trim();
    if (userId == null || userId.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Sign in required',
        text: 'Sign in before Ask JotCue can prepare a capture.',
      );
    }

    if (noteText != null) {
      final proposal = AskJotCueActionProposal(
        id: 'note:${noteText.hashCode}',
        kind: AskJotCueActionKind.noteCreate,
        userId: userId,
        previewTitle: 'Save note',
        previewText: 'Save this as a captured note:\n“$noteText”',
        noteText: noteText,
      );
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Action preview',
        text: 'I understand this as a note capture. Nothing has changed yet.',
        actionProposal: proposal,
      );
    }

    final proposal = AskJotCueActionProposal(
      id: 'capture:${draft!.kind.name}:${draft.rawText.hashCode}',
      kind: AskJotCueActionKind.structuredCapture,
      userId: userId,
      previewTitle: _capturePreviewTitle(draft),
      previewText: _capturePreviewText(draft),
      captureDraft: draft,
    );
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Action preview',
      text:
          'I understand this as a structured capture. Nothing has changed yet.',
      actionProposal: proposal,
    );
  }

  String? _explicitNoteText(String query) {
    final patterns = <RegExp>[
      RegExp(r'^remember\s+that\s+(.+)$', caseSensitive: false),
      RegExp(
        r'^(?:save|create)\s+(?:this\s+)?(?:as\s+)?(?:a\s+)?note\s*[:\-]?\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'^note\s+(?:that\s+)?(.+)$', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match == null) continue;
      final text = (match.group(1) ?? '').trim();
      if (text.isNotEmpty && text.length <= 4000) return text;
    }
    return null;
  }

  String _capturePreviewTitle(CaptureDraft draft) {
    return switch (draft.kind) {
      CaptureDraftKind.project =>
        draft.tasks.isEmpty
            ? 'Create project'
            : 'Create project + ${draft.tasks.length} ${draft.tasks.length == 1 ? 'task' : 'tasks'}',
      CaptureDraftKind.task => 'Create task',
      CaptureDraftKind.taskList => 'Create ${draft.tasks.length} tasks',
    };
  }

  String _capturePreviewText(CaptureDraft draft) {
    final lines = <String>[];
    if (draft.createsProject) {
      lines.add('Project: ${draft.projectName ?? 'New project'}');
    }
    for (final task in draft.tasks) {
      lines.add('• $task');
    }
    if (draft.deadline != null) {
      lines.add('Deadline: ${_date(draft.deadline!)}');
    }
    return lines.join('\n');
  }

  AskJotCueAnswer _taskResolutionAnswer(
    _TaskResolution resolution,
    String candidate,
  ) {
    if (resolution.ambiguous) {
      return AskJotCueAnswer(
        intent: AskJotCueIntent.action,
        title: 'Which Task?',
        text:
            'More than one Task matches "$candidate". Use the exact Task title so JotCue does not guess.',
      );
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Task not found',
      text:
          'I could not find an exact or unique Task match for "$candidate". Nothing was changed.',
    );
  }

  AskJotCueAnswer _focus(AskJotCueContext context) {
    final items = context.pulse.focusItems;
    if (items.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.focusNow,
        title: 'Focus',
        text:
            'Nothing is strongly competing for attention right now. Add a deadline, priority, or project in Plan if you want JotCue to rank open work more precisely.',
      );
    }

    final lines = <String>[];
    for (var i = 0; i < items.length; i += 1) {
      final item = items[i];
      final effort = item.task.estimatedMinutes == null
          ? ''
          : ' · ${_formatMinutes(item.task.estimatedMinutes!)}';
      lines.add('${i + 1}. ${item.task.title} — ${item.reason}$effort');
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.focusNow,
      title: 'What matters now',
      text: lines.join('\n'),
    );
  }

  AskJotCueAnswer _dueSoon(AskJotCueContext context) {
    final now = context.now;
    final cutoff = now.add(const Duration(days: 14));
    final tasks = context.tasks.where((task) {
      final due = task.dueAt;
      return !task.isCompleted &&
          due != null &&
          !due.isBefore(now) &&
          !due.isAfter(cutoff);
    }).toList()..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final today = DateTime(now.year, now.month, now.day);
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final projects = context.projects.where((project) {
      final deadline = project.deadline;
      if (!project.isActive || deadline == null) return false;
      final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
      return !deadlineDay.isBefore(today) && !deadlineDay.isAfter(cutoffDay);
    }).toList()..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    if (tasks.isEmpty && projects.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.dueSoon,
        title: 'Upcoming deadlines',
        text: 'Nothing with a known deadline is due in the next 14 days.',
      );
    }

    final lines = <String>[];
    for (final task in tasks.take(5)) {
      lines.add('• ${task.title} — ${_relativeDate(task.dueAt!, now)}');
    }
    for (final project in projects.take(3)) {
      lines.add(
        '• ${project.name} project — ${_relativeDate(project.deadline!, now)}',
      );
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.dueSoon,
      title: 'Upcoming deadlines',
      text: lines.join('\n'),
    );
  }

  AskJotCueAnswer _overdue(AskJotCueContext context) {
    final tasks =
        context.tasks
            .where(
              (task) =>
                  !task.isCompleted &&
                  task.dueAt != null &&
                  task.dueAt!.isBefore(context.now),
            )
            .toList()
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (tasks.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.overdue,
        title: 'Overdue work',
        text: 'You have no overdue tasks with known deadlines.',
      );
    }

    final lines = tasks
        .take(6)
        .map((task) {
          final days = context.now.difference(task.dueAt!).inDays;
          final label = days <= 0
              ? 'overdue today'
              : '$days ${days == 1 ? 'day' : 'days'} overdue';
          return '• ${task.title} — $label';
        })
        .join('\n');
    return AskJotCueAnswer(
      intent: AskJotCueIntent.overdue,
      title: 'Overdue work',
      text: lines,
    );
  }

  AskJotCueAnswer _capacity(AskJotCueContext context) {
    final scheduling = context.scheduling;
    if (scheduling == null || !scheduling.isConfigured) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text:
            'Planning availability is not configured yet. Set your available days and hours in Settings so JotCue can calculate realistic free time.',
      );
    }
    if (!scheduling.isEnabledDay) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text:
            'Today is not enabled as a planning day in your availability settings.',
      );
    }
    if (scheduling.needsCalendarAccess) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text:
            'JotCue needs calendar read access before it can calculate free time around fixed commitments.',
      );
    }
    final availability = scheduling.availability;
    if (availability == null) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.capacityToday,
        title: 'Today’s capacity',
        text: 'There is no usable planning window remaining today.',
      );
    }

    final accepted = context.dailyLoop.acceptedMinutes;
    final proposed = context.dailyLoop.proposedMinutes;
    final unscheduled = context.dailyLoop.unscheduledTaskCount;
    return AskJotCueAnswer(
      intent: AskJotCueIntent.capacityToday,
      title: 'Today’s capacity',
      text:
          '${_formatMinutes(availability.freeMinutes)} realistically free remains today. '
          '${_formatMinutes(accepted)} is already planned or completed and ${_formatMinutes(proposed)} is currently suggested.'
          '${unscheduled > 0 ? ' $unscheduled ${unscheduled == 1 ? 'task does' : 'tasks do'} not currently fit.' : ''}',
    );
  }

  AskJotCueAnswer _schedule(AskJotCueContext context) {
    final blocks = context.dailyLoop.todayBlocks;
    if (blocks.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.scheduleToday,
        title: 'Today’s plan',
        text: 'You do not have any accepted JotCue planning blocks today.',
      );
    }

    final lines = blocks
        .map((block) {
          final status = switch (block.status) {
            ScheduleBlockStatus.scheduled => 'scheduled',
            ScheduleBlockStatus.completed => 'completed',
            ScheduleBlockStatus.skipped => 'missed',
          };
          return '• ${_time(block.startsAt)}–${_time(block.endsAt)} ${block.title} · $status';
        })
        .join('\n');
    return AskJotCueAnswer(
      intent: AskJotCueIntent.scheduleToday,
      title: 'Today’s plan',
      text: lines,
    );
  }

  AskJotCueAnswer _nextBlock(AskJotCueContext context) {
    final block = context.dailyLoop.upNextBlock;
    if (block == null) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.nextBlock,
        title: 'Up next',
        text: 'There is no upcoming accepted JotCue block today.',
      );
    }
    final state = block.startsAt.isAfter(context.now)
        ? 'starts at ${_time(block.startsAt)}'
        : 'is in progress until ${_time(block.endsAt)}';
    return AskJotCueAnswer(
      intent: AskJotCueIntent.nextBlock,
      title: 'Up next',
      text:
          '${block.title} $state. Planned duration: ${_formatMinutes(block.duration.inMinutes)}.',
    );
  }

  AskJotCueAnswer _projects(AskJotCueContext context) {
    final active =
        context.projects.where((project) => project.isActive).toList()
          ..sort((a, b) {
            final priority = _priorityWeight(
              b.priority,
            ).compareTo(_priorityWeight(a.priority));
            if (priority != 0) return priority;
            final aDeadline = a.deadline;
            final bDeadline = b.deadline;
            if (aDeadline != null && bDeadline != null) {
              return aDeadline.compareTo(bDeadline);
            }
            if (aDeadline != null) return -1;
            if (bDeadline != null) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    if (active.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.projects,
        title: 'Active projects',
        text: 'You do not have any active Projects right now.',
      );
    }

    final tasksByProject = <String, List<Task>>{};
    for (final task in context.tasks.where((task) => !task.isCompleted)) {
      final projectId = task.projectId;
      if (projectId == null) continue;
      tasksByProject.putIfAbsent(projectId, () => []).add(task);
    }
    final lines = active
        .take(5)
        .map((project) {
          final open = tasksByProject[project.id]?.length ?? 0;
          final deadline = project.deadline == null
              ? ''
              : ' · ${_relativeDate(project.deadline!, context.now)}';
          return '• ${project.name} — $open open ${open == 1 ? 'task' : 'tasks'}$deadline';
        })
        .join('\n');
    return AskJotCueAnswer(
      intent: AskJotCueIntent.projects,
      title: 'Active projects',
      text: lines,
    );
  }

  AskJotCueAnswer _attention(AskJotCueContext context) {
    final lines = <String>[];
    final replanning = context.replanning;
    if (replanning != null && replanning.needsAttention) {
      if (replanning.pastBlockReviewCount > 0) {
        lines.add(
          '• ${replanning.pastBlockReviewCount} past planning ${replanning.pastBlockReviewCount == 1 ? 'block needs' : 'blocks need'} Completed/Missed review.',
        );
      }
      if (replanning.conflictCount > 0) {
        lines.add(
          '• ${replanning.conflictCount} scheduled ${replanning.conflictCount == 1 ? 'block conflicts' : 'blocks conflict'} with calendar or availability.',
        );
      }
      if (replanning.urgentCapacityCount > 0) {
        lines.add(
          '• ${replanning.urgentCapacityCount} urgent ${replanning.urgentCapacityCount == 1 ? 'capacity problem needs' : 'capacity problems need'} a decision.',
        );
      }
    }
    if (context.pulse.overdueCount > 0) {
      lines.add(
        '• ${context.pulse.overdueCount} overdue ${context.pulse.overdueCount == 1 ? 'task' : 'tasks'}.',
      );
    }
    final undatedHigh = context.tasks.where((task) {
      return !task.isCompleted &&
          task.dueAt == null &&
          (task.priority == PriorityLevel.high ||
              task.priority == PriorityLevel.critical);
    }).length;
    if (undatedHigh > 0) {
      lines.add(
        '• $undatedHigh high-priority ${undatedHigh == 1 ? 'task has' : 'tasks have'} no deadline.',
      );
    }

    if (lines.isEmpty) {
      return const AskJotCueAnswer(
        intent: AskJotCueIntent.needsAttention,
        title: 'Needs attention',
        text:
            'JotCue is not currently flagging any planning issues that need review.',
      );
    }
    return AskJotCueAnswer(
      intent: AskJotCueIntent.needsAttention,
      title: 'Needs attention',
      text: lines.join('\n'),
    );
  }

  AskJotCueAnswer _help() {
    return const AskJotCueAnswer(
      intent: AskJotCueIntent.help,
      title: 'Ask JotCue',
      text:
          'I can answer from your current JotCue plan. Try:\n'
          '• What should I do now?\n'
          '• What’s due soon?\n'
          '• Am I behind on anything?\n'
          '• How much time do I have today?\n'
          '• What’s next?\n'
          '• What needs attention?\n'
          '• Which projects are active?\n'
          '• Mark Revise chapter 4 done\n'
          '• Set Revise chapter 4 priority high\n'
          '• Set Revise chapter 4 due Sep 30\n'
          '• Put Revise chapter 4 under Thesis\n'
          '• Set Revise chapter 4 estimate to 90 minutes\n'
          '• Make Submit application depend on Finish CV\n'
          '• Application is waiting for Susan\n'
          '• Move Revise chapter 4 tomorrow at 15:00\n'
          '• Add task Submit HPC report by Sep 30\n'
          '• Create project called STG App with deadline Oct 30\n'
          '• Remember that Sarah moved the meeting to Friday',
    );
  }

  AskJotCueAnswer _unknown() {
    return const AskJotCueAnswer(
      intent: AskJotCueIntent.unknown,
      title: 'I can help with your plan',
      text:
          'I don’t safely understand that request yet. Ask about focus, deadlines, overdue work, capacity, schedules, projects, or review items. I can also preview explicit changes including Task completion, Task planning metadata, moving one accepted JotCue block, and creating Tasks, Projects, or Notes. Unsupported requests never change anything.',
    );
  }
}

class _TaskResolution {
  const _TaskResolution({this.task, this.ambiguous = false});

  final Task? task;
  final bool ambiguous;
}

_TaskResolution _resolveTask(String candidate, List<Task> tasks) {
  final needle = _normalize(candidate);
  if (needle.isEmpty) return const _TaskResolution();

  final exact = tasks
      .where((task) => _normalize(task.title) == needle)
      .toList(growable: false);
  if (exact.length == 1) return _TaskResolution(task: exact.single);
  if (exact.length > 1) return const _TaskResolution(ambiguous: true);

  final partial = tasks
      .where((task) {
        final title = _normalize(task.title);
        return title.contains(needle) || needle.contains(title);
      })
      .toList(growable: false);
  if (partial.length == 1) return _TaskResolution(task: partial.single);
  if (partial.length > 1) return const _TaskResolution(ambiguous: true);
  return const _TaskResolution();
}

class _ProjectResolution {
  const _ProjectResolution({this.project, this.ambiguous = false});

  final Project? project;
  final bool ambiguous;
}

_ProjectResolution _resolveProject(String candidate, List<Project> projects) {
  final needle = _normalize(candidate);
  if (needle.isEmpty) return const _ProjectResolution();

  final exact = projects
      .where((project) => _normalize(project.name) == needle)
      .toList(growable: false);
  if (exact.length == 1) return _ProjectResolution(project: exact.single);
  if (exact.length > 1) return const _ProjectResolution(ambiguous: true);

  final partial = projects
      .where((project) {
        final name = _normalize(project.name);
        return name.contains(needle) || needle.contains(name);
      })
      .toList(growable: false);
  if (partial.length == 1) return _ProjectResolution(project: partial.single);
  if (partial.length > 1) return const _ProjectResolution(ambiguous: true);
  return const _ProjectResolution();
}

DateTime? _parsePlanningDueDate(String value, DateTime now) {
  final normalized = value.trim().toLowerCase().replaceAll(',', '');
  if (normalized == 'today') {
    return DateTime(now.year, now.month, now.day, 23, 59);
  }
  if (normalized == 'tomorrow') {
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59);
  }

  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
  if (iso != null) {
    final year = int.tryParse(iso.group(1)!);
    final month = int.tryParse(iso.group(2)!);
    final day = int.tryParse(iso.group(3)!);
    return _validEndOfDay(year, month, day);
  }

  final monthFirst = RegExp(
    r'^([a-z]+)\s+(\d{1,2})(?:\s+(\d{4}))?$',
  ).firstMatch(normalized);
  if (monthFirst != null) {
    final month = _monthNumber(monthFirst.group(1)!);
    final day = int.tryParse(monthFirst.group(2)!);
    final explicitYear = int.tryParse(monthFirst.group(3) ?? '');
    if (month == null || day == null) return null;
    var year = explicitYear ?? now.year;
    var parsed = _validEndOfDay(year, month, day);
    if (parsed == null) return null;
    if (explicitYear == null && parsed.isBefore(now)) {
      year += 1;
      parsed = _validEndOfDay(year, month, day);
    }
    return parsed;
  }

  final dayFirst = RegExp(
    r'^(\d{1,2})\s+([a-z]+)(?:\s+(\d{4}))?$',
  ).firstMatch(normalized);
  if (dayFirst != null) {
    final day = int.tryParse(dayFirst.group(1)!);
    final month = _monthNumber(dayFirst.group(2)!);
    final explicitYear = int.tryParse(dayFirst.group(3) ?? '');
    if (month == null || day == null) return null;
    var year = explicitYear ?? now.year;
    var parsed = _validEndOfDay(year, month, day);
    if (parsed == null) return null;
    if (explicitYear == null && parsed.isBefore(now)) {
      year += 1;
      parsed = _validEndOfDay(year, month, day);
    }
    return parsed;
  }
  return null;
}

DateTime? _validEndOfDay(int? year, int? month, int? day) {
  if (year == null || month == null || day == null) return null;
  final value = DateTime(year, month, day, 23, 59);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}

int? _monthNumber(String value) {
  return switch (value.toLowerCase()) {
    'jan' || 'january' => 1,
    'feb' || 'february' => 2,
    'mar' || 'march' => 3,
    'apr' || 'april' => 4,
    'may' => 5,
    'jun' || 'june' => 6,
    'jul' || 'july' => 7,
    'aug' || 'august' => 8,
    'sep' || 'sept' || 'september' => 9,
    'oct' || 'october' => 10,
    'nov' || 'november' => 11,
    'dec' || 'december' => 12,
    _ => null,
  };
}

int? _parseEffortMinutes(String value) {
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(minutes?|mins?|hours?|hrs?|h|m)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount <= 0) return null;
  final unit = match.group(2)!.toLowerCase();
  final minutes = unit.startsWith('h') ? (amount * 60).round() : amount.round();
  if (minutes <= 0 || minutes > 10080) return null;
  return minutes;
}

bool _sameCalendarDate(DateTime? a, DateTime b) {
  return a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

PriorityLevel _priorityFromWord(String? value) {
  return switch (value?.toLowerCase()) {
    'critical' => PriorityLevel.critical,
    'high' => PriorityLevel.high,
    'medium' => PriorityLevel.medium,
    'low' => PriorityLevel.low,
    _ => PriorityLevel.none,
  };
}

String _priorityName(PriorityLevel value) {
  return switch (value) {
    PriorityLevel.none => 'no',
    PriorityLevel.low => 'low',
    PriorityLevel.medium => 'medium',
    PriorityLevel.high => 'high',
    PriorityLevel.critical => 'critical',
  };
}

DateTime? _parseMoveDate(String value, DateTime now) {
  final normalized = value.toLowerCase();
  if (normalized == 'today') {
    return DateTime(now.year, now.month, now.day);
  }
  if (normalized == 'tomorrow') {
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

(int, int)? _parseClock(String hourText, String? minuteText, String? meridiem) {
  var hour = int.tryParse(hourText);
  final minute = int.tryParse(minuteText ?? '0');
  if (hour == null || minute == null || minute < 0 || minute > 59) {
    return null;
  }
  final suffix = meridiem?.toLowerCase();
  if (suffix != null) {
    if (hour < 1 || hour > 12) return null;
    if (suffix == 'am') {
      hour = hour == 12 ? 0 : hour;
    } else {
      hour = hour == 12 ? 12 : hour + 12;
    }
  } else if (hour < 0 || hour > 23) {
    return null;
  }
  return (hour, minute);
}

String _date(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _dateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day ${_time(value)}';
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9' ]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _containsAny(String value, List<String> phrases) {
  return phrases.any(value.contains);
}

int _priorityWeight(PriorityLevel priority) {
  return switch (priority) {
    PriorityLevel.critical => 4,
    PriorityLevel.high => 3,
    PriorityLevel.medium => 2,
    PriorityLevel.low => 1,
    PriorityLevel.none => 0,
  };
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _relativeDate(DateTime value, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final days = date.difference(today).inDays;
  if (days <= 0) return 'due today';
  if (days == 1) return 'due tomorrow';
  if (days <= 13) return 'due in $days days';
  return '${_month(value.month)} ${value.day}';
}

String _month(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
