import 'package:flutter/material.dart';

import '../../../../core/models/priority_level.dart';
import '../../../../core/services/app_theme.dart';
import '../../../personal_graph/models/personal_graph.dart';
import '../../../projects/models/project.dart';
import '../../../tasks/models/task.dart';
import '../../../tasks/models/task_action_cue.dart';
import '../../../tasks/models/task_metadata_update.dart';

Future<TaskMetadataUpdate?> showTaskPlanningSheet({
  required BuildContext context,
  required Task task,
  required List<Project> projects,
  PersonalGraphTaskContext? relatedContext,
  List<Task> availableTasks = const <Task>[],
  TaskActionCue? actionCue,
}) {
  return showModalBottomSheet<TaskMetadataUpdate>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TaskPlanningSheet(
      task: task,
      projects: projects,
      relatedContext: relatedContext,
      availableTasks: availableTasks,
      actionCue: actionCue,
    ),
  );
}

class _TaskPlanningSheet extends StatefulWidget {
  const _TaskPlanningSheet({
    required this.task,
    required this.projects,
    this.relatedContext,
    this.availableTasks = const <Task>[],
    this.actionCue,
  });

  final Task task;
  final List<Project> projects;
  final PersonalGraphTaskContext? relatedContext;
  final List<Task> availableTasks;
  final TaskActionCue? actionCue;

  @override
  State<_TaskPlanningSheet> createState() => _TaskPlanningSheetState();
}

const _unassignedProjectValue = '__jotcue_unassigned__';

class _TaskPlanningSheetState extends State<_TaskPlanningSheet> {
  late String? _projectId;
  late DateTime? _dueAt;
  late PriorityLevel _priority;
  late bool _isFlexible;
  late final TextEditingController _effortController;
  late final TextEditingController _waitingForController;
  late final List<String> _dependencyIds;

  @override
  void initState() {
    super.initState();
    final knownProjectIds = widget.projects
        .map((project) => project.id)
        .toSet();
    _projectId = knownProjectIds.contains(widget.task.projectId)
        ? widget.task.projectId
        : null;
    _dueAt = widget.task.dueAt;
    _priority = widget.task.priority;
    _isFlexible = widget.task.isFlexible;
    _effortController = TextEditingController(
      text: widget.task.estimatedMinutes?.toString() ?? '',
    );
    _waitingForController = TextEditingController(
      text: widget.task.waitingFor ?? '',
    );
    _dependencyIds = [...widget.task.dependsOnTaskIds];
  }

  @override
  void dispose() {
    _effortController.dispose();
    _waitingForController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Plan task', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.task.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (widget.relatedContext?.hasRelatedContext == true) ...[
              const SizedBox(height: AppSpacing.md),
              _RelatedContextCard(context: widget.relatedContext!),
            ],
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _projectId ?? _unassignedProjectValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Project',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: _unassignedProjectValue,
                  child: Text('Unassigned'),
                ),
                ...widget.projects.map(
                  (project) => DropdownMenuItem<String>(
                    value: project.id,
                    child: Text(project.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _projectId = value == _unassignedProjectValue ? null : value;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateField(
              label: 'Due date',
              value: _dueAt,
              onPick: _pickDueDate,
              onClear: _dueAt == null
                  ? null
                  : () => setState(() => _dueAt = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<PriorityLevel>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: PriorityLevel.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(_priorityLabel(priority)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _priority = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('task-effort-minutes'),
              controller: _effortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated effort',
                hintText: 'Minutes, e.g. 90',
                prefixIcon: Icon(Icons.timelapse_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Dependencies & blockers',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use explicit prerequisites when another JotCue task must finish first. Use Waiting for for an external person, reply, approval, or event.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_dependencyIds.isNotEmpty)
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final dependencyId in _dependencyIds)
                    InputChip(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          _taskTitle(dependencyId),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onDeleted: () =>
                          setState(() => _dependencyIds.remove(dependencyId)),
                    ),
                ],
              ),
            if (_dependencyIds.isNotEmpty)
              const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              key: const ValueKey('task-add-dependency'),
              initialValue: null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Add prerequisite task',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: _dependencyOptions()
                  .map(
                    (task) => DropdownMenuItem<String>(
                      value: task.id,
                      child: Text(
                        task.isCompleted ? '${task.title} · done' : task.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null || _dependencyIds.contains(value)) return;
                setState(() => _dependencyIds.add(value));
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('task-waiting-for'),
              controller: _waitingForController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Waiting for',
                hintText: 'e.g. supervisor feedback',
                prefixIcon: Icon(Icons.hourglass_top_rounded),
              ),
            ),
            if (widget.actionCue?.isBlocked == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.actionCue!.shortLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Flexible'),
              subtitle: const Text(
                'JotCue may suggest moving this task when schedules change. In Trusted mode, it can auto-move only when your device safety controls allow it.',
              ),
              value: _isFlexible,
              onChanged: (value) => setState(() => _isFlexible = value),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _save,
              child: const Text('Save planning details'),
            ),
          ],
        ),
      ),
    );
  }

  List<Task> _dependencyOptions() {
    final result = widget.availableTasks
        .where(
          (task) =>
              task.id != widget.task.id && !_dependencyIds.contains(task.id),
        )
        .toList();
    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  String _taskTitle(String taskId) {
    for (final task in widget.availableTasks) {
      if (task.id == taskId) return task.title;
    }
    return 'Missing task';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _dueAt = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  void _save() {
    final rawEffort = _effortController.text.trim();
    final effort = rawEffort.isEmpty ? null : int.tryParse(rawEffort);
    if (rawEffort.isNotEmpty && (effort == null || effort <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estimated effort must be a positive number.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      TaskMetadataUpdate(
        projectId: _projectId,
        clearProjectId: _projectId == null,
        dueAt: _dueAt,
        clearDueAt: _dueAt == null,
        priority: _priority,
        estimatedMinutes: effort,
        clearEstimatedMinutes: effort == null,
        isFlexible: _isFlexible,
        dependsOnTaskIds: List.unmodifiable(_dependencyIds),
        waitingFor: _waitingForController.text.trim().isEmpty
            ? null
            : _waitingForController.text.trim(),
        clearWaitingFor: _waitingForController.text.trim().isEmpty,
      ),
    );
  }
}

class _RelatedContextCard extends StatelessWidget {
  const _RelatedContextCard({required this.context});

  final PersonalGraphTaskContext context;

  @override
  Widget build(BuildContext buildContext) {
    final items = <Widget>[];
    final note = context.sourceNote;
    final project = context.project;
    final deadline = context.deadline;
    final nextBlock = context.nextScheduleBlock(DateTime.now());

    if (note != null) {
      items.add(
        _ContextChip(icon: Icons.note_outlined, label: 'Note: ${note.label}'),
      );
    }
    if (project != null) {
      items.add(
        _ContextChip(
          icon: Icons.folder_outlined,
          label: 'Project: ${project.label}',
        ),
      );
    }
    for (final prerequisite in context.prerequisiteTasks) {
      items.add(
        _ContextChip(
          icon: Icons.account_tree_outlined,
          label: 'Depends on: ${prerequisite.label}',
        ),
      );
    }
    if (deadline?.startsAt != null) {
      items.add(
        _ContextChip(
          icon: Icons.event_outlined,
          label: 'Deadline: ${_formatDate(deadline!.startsAt!)}',
        ),
      );
    }
    if (nextBlock?.startsAt != null && nextBlock?.endsAt != null) {
      final extra = context.scheduleBlocks.length > 1
          ? ' +${context.scheduleBlocks.length - 1} more'
          : '';
      items.add(
        _ContextChip(
          icon: Icons.schedule_outlined,
          label:
              'Scheduled: ${_formatDateTime(nextBlock!.startsAt!)}–${_formatTime(nextBlock.endsAt!)}$extra',
        ),
      );
    }
    if (context.integrityIssues.isNotEmpty) {
      items.add(
        const _ContextChip(
          icon: Icons.link_off_rounded,
          label: 'Some related context needs repair',
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(buildContext).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Related context',
              style: Theme.of(buildContext).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Derived locally from the Note, Project, deadline, and accepted schedule linked to this task.',
              style: Theme.of(buildContext).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: items,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _formatDateTime(DateTime value) {
  return '${_formatDate(value)}, ${_formatTime(value)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.event_outlined),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(value == null ? 'No date' : _formatDate(value!)),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear date',
              icon: const Icon(Icons.clear_rounded),
            ),
          TextButton(onPressed: onPick, child: const Text('Choose')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = <String>[
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _priorityLabel(PriorityLevel priority) {
  return switch (priority) {
    PriorityLevel.none => 'No priority',
    PriorityLevel.low => 'Low',
    PriorityLevel.medium => 'Medium',
    PriorityLevel.high => 'High',
    PriorityLevel.critical => 'Critical',
  };
}
