import 'package:flutter/material.dart';

import '../../../../core/models/priority_level.dart';
import '../../../../core/services/app_theme.dart';
import '../../../projects/models/project.dart';

enum ProjectEditAction { save, delete }

class ProjectEditResult {
  const ProjectEditResult({required this.action, required this.project});

  final ProjectEditAction action;
  final Project project;
}

Future<ProjectEditResult?> showProjectEditSheet({
  required BuildContext context,
  required Project project,
}) {
  return showModalBottomSheet<ProjectEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ProjectEditSheet(project: project),
  );
}

class _ProjectEditSheet extends StatefulWidget {
  const _ProjectEditSheet({required this.project});

  final Project project;

  @override
  State<_ProjectEditSheet> createState() => _ProjectEditSheetState();
}

class _ProjectEditSheetState extends State<_ProjectEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetMinutesController;
  late ProjectStatus _status;
  late PriorityLevel _priority;
  late DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _descriptionController = TextEditingController(
      text: widget.project.description,
    );
    _targetMinutesController = TextEditingController(
      text: widget.project.targetMinutesPerWeek?.toString() ?? '',
    );
    _status = widget.project.status;
    _priority = widget.project.priority;
    _deadline = widget.project.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetMinutesController.dispose();
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
            Text(
              'Edit project',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('edit-project-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('edit-project-description'),
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ProjectStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.track_changes_rounded),
              ),
              items: ProjectStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
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
            _DeadlineField(
              value: _deadline,
              onPick: _pickDeadline,
              onClear: _deadline == null
                  ? null
                  : () => setState(() => _deadline = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('project-target-minutes'),
              controller: _targetMinutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weekly target',
                hintText: 'Minutes per week, optional',
                prefixIcon: Icon(Icons.timelapse_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _save, child: const Text('Save project')),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: const ValueKey('delete-project-action'),
              onPressed: () => Navigator.of(context).pop(
                ProjectEditResult(
                  action: ProjectEditAction.delete,
                  project: widget.project,
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete project'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now;
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
      _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project name cannot be empty.')),
      );
      return;
    }

    final rawTarget = _targetMinutesController.text.trim();
    final target = rawTarget.isEmpty ? null : int.tryParse(rawTarget);
    if (rawTarget.isNotEmpty && (target == null || target < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly target must be zero or more.')),
      );
      return;
    }

    final updated = widget.project.copyWith(
      name: name,
      description: _descriptionController.text.trim(),
      status: _status,
      priority: _priority,
      deadline: _deadline,
      targetMinutesPerWeek: target,
    );

    Navigator.of(
      context,
    ).pop(ProjectEditResult(action: ProjectEditAction.save, project: updated));
  }
}

class _DeadlineField extends StatelessWidget {
  const _DeadlineField({
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Deadline',
        prefixIcon: Icon(Icons.event_outlined),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(value == null ? 'No deadline' : _formatDate(value!)),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear deadline',
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

String _statusLabel(ProjectStatus status) {
  return switch (status) {
    ProjectStatus.active => 'Active',
    ProjectStatus.paused => 'Paused',
    ProjectStatus.completed => 'Completed',
    ProjectStatus.archived => 'Archived',
  };
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
