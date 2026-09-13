import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/priority_level.dart';
import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/adaptive_shell.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../projects/models/project.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/schedule_proposal.dart';
import '../../scheduling/presentation/widgets/scheduling_preferences_sheet.dart';
import '../../scheduling/presentation/widgets/suggested_schedule_section.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../settings/models/user_settings.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/plan_overview.dart';
import '../providers/planning_providers.dart';
import 'widgets/project_edit_sheet.dart';
import 'widgets/task_planning_sheet.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, this.embedded = false, this.now});

  final bool embedded;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final projects = projectsAsync.asData?.value ?? const <Project>[];
    final tasks = ref.watch(tasksProvider);
    final currentTime = now ?? DateTime.now();
    final overview = PlanOverview.build(
      projects: projects,
      tasks: tasks,
      now: currentTime,
    );
    final planningDate = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final scheduleAsync = ref.watch(schedulingDayProvider(planningDate));

    final usesBottomNavigation =
        MediaQuery.sizeOf(context).width < AdaptiveShell.tabletBreakpoint;

    return ColoredBox(
      color: embedded ? Colors.transparent : AppColors.canvasFor(context),
      child: SafeArea(
        top: !embedded,
        bottom: false,
        child: CustomScrollView(
          key: const ValueKey('plan-screen-scroll'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                usesBottomNavigation ? 116 : AppSpacing.lg,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PlanHeader(
                    onCreateProject: () => _createProject(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryGrid(overview: overview),
                  if (projectsAsync.hasError) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SyncNotice(
                      message:
                          'Projects are showing from local data. Cloud sync will retry automatically.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SuggestedScheduleSection(
                    state: scheduleAsync,
                    onConfigure: () => _configureAvailability(context, ref),
                    onRequestCalendar: () =>
                        _requestCalendarAccess(context, ref, planningDate),
                    onAccept: (proposal) =>
                        _acceptProposal(context, ref, planningDate, proposal),
                    onRemoveBlock: (block) =>
                        _removeScheduleBlock(context, ref, planningDate, block),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Projects',
                    subtitle: overview.projects.isEmpty
                        ? 'Create a project to group work around an outcome.'
                        : '${overview.activeProjectCount} active',
                    trailing: TextButton.icon(
                      onPressed: () => _createProject(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (overview.projects.isEmpty)
                    AppCard(
                      color: AppColors.lavender,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.folder_copy_outlined, size: 28),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No projects yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Projects give your tasks context without changing the notes they came from.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.tonalIcon(
                            onPressed: () => _createProject(context, ref),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create project'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...overview.projects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ProjectCard(
                          project: project,
                          overview: overview,
                          onTap: () => _editProject(context, ref, project),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Tasks',
                    subtitle: overview.openTasks.isEmpty
                        ? 'Nothing open right now.'
                        : '${overview.openTasks.length} open · ${overview.unassignedTasks.length} unassigned',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (overview.openTasks.isEmpty)
                    const EmptyState(
                      title: 'No open tasks',
                      message:
                          'Tasks you write in notes will appear here after the note has a stable task identity.',
                      icon: Icons.task_alt_rounded,
                    )
                  else
                    ...overview.openTasks
                        .take(10)
                        .map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: _TaskRow(
                              task: task,
                              projects: overview.projects,
                              now: currentTime,
                              onTap: () => _editTask(
                                context,
                                ref,
                                task,
                                overview.projects,
                              ),
                            ),
                          ),
                        ),
                  if (overview.openTasks.length > 10) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '+ ${overview.openTasks.length - 10} more open tasks',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureAvailability(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }
    final settings =
        ref.read(currentUserSettingsProvider).asData?.value ??
        UserSettings.defaults();
    final updated = await showSchedulingPreferencesSheet(
      context: context,
      initial: settings.schedulingPreferences,
    );
    if (updated == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(userSettingsRepositoryProvider)
          .updateSchedulingPreferences(user.uid, updated);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save availability: $error')),
      );
    }
  }

  Future<void> _requestCalendarAccess(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    try {
      final granted = await ref
          .read(deviceCalendarReadServiceProvider)
          .requestAccess();
      ref.invalidate(calendarReadAccessProvider);
      ref.invalidate(schedulingDayProvider(date));
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Calendar access was not granted. JotCue will not propose times that could conflict with your device calendar.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request calendar access: $error')),
      );
    }
  }

  Future<void> _acceptProposal(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    ScheduleProposal proposal,
  ) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }
    try {
      await ref
          .read(scheduleBlocksRepositoryProvider)
          .acceptProposal(userId: user.uid, proposal: proposal);
      ref.invalidate(schedulingDayProvider(date));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept this time: $error')),
      );
    }
  }

  Future<void> _removeScheduleBlock(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    ScheduleBlock block,
  ) async {
    try {
      await ref
          .read(scheduleBlocksRepositoryProvider)
          .deleteBlock(block.userId, block.id);
      ref.invalidate(schedulingDayProvider(date));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove planned block: $error')),
      );
    }
  }

  Future<void> _editTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
    List<Project> projects,
  ) async {
    final update = await showTaskPlanningSheet(
      context: context,
      task: task,
      projects: projects,
    );
    if (update == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(planningServiceProvider)
          .updateTaskMetadata(
            userId: task.userId,
            noteId: task.sourceNoteId,
            taskId: task.id,
            update: update,
          );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
    }
  }

  Future<void> _editProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final result = await showProjectEditSheet(
      context: context,
      project: project,
    );
    if (result == null || !context.mounted) {
      return;
    }

    if (result.action == ProjectEditAction.delete) {
      await _confirmDeleteProject(context, ref, project);
      return;
    }

    try {
      await ref.read(planningServiceProvider).updateProject(result.project);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update project: $error')),
      );
    }
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          '“${project.name}” will be deleted. Its tasks will stay in their notes and become unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete project'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final clearedCount = await ref
          .read(planningServiceProvider)
          .deleteProjectAndUnassignTasks(
            userId: project.userId,
            projectId: project.id,
          );
      if (!context.mounted) {
        return;
      }
      final suffix = clearedCount == 0
          ? ''
          : ' ${clearedCount == 1 ? '1 task is' : '$clearedCount tasks are'} now unassigned.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Project deleted.$suffix')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete project: $error')),
      );
    }
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }

    final draft = await showModalBottomSheet<_ProjectDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CreateProjectSheet(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(projectsRepositoryProvider)
          .createProject(
            userId: user.uid,
            name: draft.name,
            description: draft.description,
          );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create project: $error')),
      );
    }
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Projects and tasks, connected to the notes they came from.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: onCreateProject,
          tooltip: 'Create project',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview});

  final PlanOverview overview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 650;
        final cards = [
          _SummaryCard(
            label: 'Active projects',
            value: '${overview.activeProjectCount}',
            icon: Icons.folder_open_rounded,
            color: AppColors.lavender,
          ),
          _SummaryCard(
            label: 'Open tasks',
            value: '${overview.openTasks.length}',
            icon: Icons.checklist_rounded,
            color: AppColors.sky,
          ),
          _SummaryCard(
            label: 'Due soon',
            value: '${overview.dueSoonTasks.length}',
            icon: Icons.schedule_rounded,
            color: AppColors.butter,
          ),
        ];

        if (wide) {
          return Row(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index != cards.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              cards[index],
              if (index != cards.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 23),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.overview,
    required this.onTap,
  });

  final Project project;
  final PlanOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = overview.totalTasksForProject(project.id);
    final completed = overview.completedTasksForProject(project.id);
    final progress = overview.progressForProject(project.id);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return AppCard(
      onTap: onTap,
      borderColor: project.isActive ? AppColors.panelBorderFor(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _StatusPill(status: project.status),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
          if (project.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              project.description.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (project.deadline != null)
                _MetaLabel(
                  icon: Icons.event_outlined,
                  label: _formatDate(project.deadline!),
                ),
              if (project.priority != PriorityLevel.none)
                _MetaLabel(
                  icon: Icons.flag_outlined,
                  label: _priorityLabel(project.priority),
                ),
              if (project.targetMinutesPerWeek != null)
                _MetaLabel(
                  icon: Icons.timelapse_rounded,
                  label: _formatMinutes(project.targetMinutesPerWeek!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: total == 0 ? 0 : progress,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                total == 0 ? 'No tasks' : '$completed/$total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.projects,
    required this.now,
    required this.onTap,
  });

  final Task task;
  final List<Project> projects;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final project = _projectFor(task.projectId);
    final overdue = task.dueAt?.isBefore(now) ?? false;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.radio_button_unchecked_rounded,
              size: 19,
              color: overdue ? AppColors.warning : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 3,
                  children: [
                    Text(
                      project?.name ?? 'Unassigned',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (task.dueAt != null)
                      Text(
                        overdue
                            ? 'Overdue · ${_formatDate(task.dueAt!)}'
                            : 'Due ${_formatDate(task.dueAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: overdue ? AppColors.warning : null,
                          fontWeight: overdue ? FontWeight.w700 : null,
                        ),
                      ),
                    if (task.estimatedMinutes != null)
                      Text(
                        _formatMinutes(task.estimatedMinutes!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }

  Project? _projectFor(String? projectId) {
    if (projectId == null) {
      return null;
    }
    for (final project in projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ProjectStatus.active => 'Active',
      ProjectStatus.paused => 'Paused',
      ProjectStatus.completed => 'Done',
      ProjectStatus.archived => 'Archived',
    };
    final color = switch (status) {
      ProjectStatus.active => AppColors.mint,
      ProjectStatus.paused => AppColors.butter,
      ProjectStatus.completed => AppColors.sky,
      ProjectStatus.archived => AppColors.lavender,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textFor(color),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.butter,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 19),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _CreateProjectSheet extends StatefulWidget {
  const _CreateProjectSheet();

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New project', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start with a name. Planning details can be added in later updates.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey('new-project-name'),
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Project name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('new-project-description'),
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop(
                        _ProjectDraft(
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim(),
                        ),
                      );
                    },
              child: const Text('Create project'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDraft {
  const _ProjectDraft({required this.name, required this.description});

  final String name;
  final String description;
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
  return '${value.day} ${months[value.month - 1]}';
}

String _formatMinutes(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainder}m';
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
