import 'package:flutter/material.dart';

import '../../../../core/models/priority_level.dart';
import '../../../../core/services/app_theme.dart';
import '../../../projects/models/project.dart';
import '../../../tasks/models/task.dart';
import '../../../tasks/models/task_metadata_update.dart';

Future<TaskMetadataUpdate?> showTaskPlanningSheet({
  required BuildContext context,
  required Task task,
  required List<Project> projects,
}) {
  return showModalBottomSheet<TaskMetadataUpdate>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TaskPlanningSheet(task: task, projects: projects),
  );
}

class _TaskPlanningSheet extends StatefulWidget {
  const _TaskPlanningSheet({required this.task, required this.projects});

  final Task task;
  final List<Project> projects;

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
  }

  @override
  void dispose() {
    _effortController.dispose();
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
      ),
    );
  }
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
