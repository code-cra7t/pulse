import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../../projects/models/project.dart';
import '../../tasks/models/task.dart';
import '../models/automation_safety_preferences.dart';

Future<AutomationSafetyPreferences?> showAutomationSafetySheet({
  required BuildContext context,
  required AutomationSafetyPreferences initial,
  required List<Task> tasks,
  required List<Project> projects,
}) {
  return showModalBottomSheet<AutomationSafetyPreferences>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AutomationSafetySheet(
      initial: initial,
      tasks: tasks,
      projects: projects,
    ),
  );
}

class _AutomationSafetySheet extends StatefulWidget {
  const _AutomationSafetySheet({
    required this.initial,
    required this.tasks,
    required this.projects,
  });

  final AutomationSafetyPreferences initial;
  final List<Task> tasks;
  final List<Project> projects;

  @override
  State<_AutomationSafetySheet> createState() => _AutomationSafetySheetState();
}

class _AutomationSafetySheetState extends State<_AutomationSafetySheet> {
  late bool _paused;
  late Set<String> _excludedTaskIds;
  late Set<String> _excludedProjectIds;

  @override
  void initState() {
    super.initState();
    _paused = widget.initial.paused;
    _excludedTaskIds = {...widget.initial.excludedTaskIds};
    _excludedProjectIds = {...widget.initial.excludedProjectIds};
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final eligibleTasks = widget.tasks
        .where((task) => !task.isCompleted && task.isFlexible)
        .toList(growable: false);
    final activeProjects = widget.projects
        .where((project) => project.isActive)
        .toList(growable: false);

    return SingleChildScrollView(
      key: const ValueKey('automation-safety-sheet'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trusted automation safety',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'These controls apply only to trusted local schedule moves on this device.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            key: const ValueKey('trusted-automation-pause-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Pause trusted moves'),
            subtitle: const Text(
              'JotCue can still detect conflicts and suggest changes, but will not move blocks automatically.',
            ),
            value: _paused,
            onChanged: (value) => setState(() => _paused = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Bounce protection: after JotCue moves a block—or you undo that move—the same block cannot be auto-moved again for 30 minutes. Calendar-linked blocks and sensitive decisions still require approval.',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(
            title: 'Task exclusions',
            subtitle: eligibleTasks.isEmpty
                ? 'No flexible open tasks are available.'
                : 'Turn off trusted moves for individual tasks.',
          ),
          if (eligibleTasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            ...eligibleTasks.map(
              (task) => CheckboxListTile(
                key: ValueKey('automation-task-${task.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  task.projectId == null
                      ? 'Unassigned task'
                      : _projectName(task.projectId!, widget.projects),
                ),
                value: !_excludedTaskIds.contains(task.id),
                onChanged: (allowed) => setState(() {
                  if (allowed == true) {
                    _excludedTaskIds.remove(task.id);
                  } else {
                    _excludedTaskIds.add(task.id);
                  }
                }),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(
            title: 'Project exclusions',
            subtitle: activeProjects.isEmpty
                ? 'No active projects are available.'
                : 'Turning a project off blocks trusted moves for every task assigned to it.',
          ),
          if (activeProjects.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            ...activeProjects.map(
              (project) => CheckboxListTile(
                key: ValueKey('automation-project-${project.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: !_excludedProjectIds.contains(project.id),
                onChanged: (allowed) => setState(() {
                  if (allowed == true) {
                    _excludedProjectIds.remove(project.id);
                  } else {
                    _excludedProjectIds.add(project.id);
                  }
                }),
              ),
            ),
          ],
          if (_excludedTaskIds.isNotEmpty ||
              _excludedProjectIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () => setState(() {
                _excludedTaskIds.clear();
                _excludedProjectIds.clear();
              }),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Allow all eligible tasks and projects'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                AutomationSafetyPreferences(
                  paused: _paused,
                  excludedTaskIds: Set.unmodifiable(_excludedTaskIds),
                  excludedProjectIds: Set.unmodifiable(_excludedProjectIds),
                ),
              ),
              child: const Text('Save safety controls'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _projectName(String projectId, List<Project> projects) {
  for (final project in projects) {
    if (project.id == projectId) {
      return project.name;
    }
  }
  return 'Assigned project';
}
