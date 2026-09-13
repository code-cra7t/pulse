import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/priority_level.dart';
import '../../../core/services/app_theme.dart';
import '../../../core/widgets/adaptive_shell.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../planning/presentation/widgets/task_planning_sheet.dart';
import '../../planning/providers/planning_providers.dart';
import '../../projects/models/project.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/pulse_overview.dart';

class PulseScreen extends ConsumerWidget {
  const PulseScreen({
    super.key,
    this.embedded = false,
    this.now,
    this.displayName,
    this.onOpenPlan,
  });

  final bool embedded;
  final DateTime? now;
  final String? displayName;
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final projects = projectsAsync.asData?.value ?? const <Project>[];
    final tasks = ref.watch(tasksProvider);
    final currentTime = now ?? DateTime.now();
    final overview = PulseOverview.build(
      projects: projects,
      tasks: tasks,
      now: currentTime,
    );
    final usesBottomNavigation =
        MediaQuery.sizeOf(context).width < AdaptiveShell.tabletBreakpoint;

    return ColoredBox(
      color: embedded ? Colors.transparent : AppColors.canvasFor(context),
      child: SafeArea(
        top: !embedded,
        bottom: false,
        child: CustomScrollView(
          key: const ValueKey('pulse-screen-scroll'),
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
                  _PulseHeader(
                    now: currentTime,
                    displayName: displayName,
                    onOpenPlan: onOpenPlan,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DaySnapshot(overview: overview),
                  if (projectsAsync.hasError) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const _SyncNotice(),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Focus',
                    subtitle: overview.focusItems.isEmpty
                        ? 'Nothing is asking for your attention right now.'
                        : 'The strongest signals from your current plan.',
                    trailing: onOpenPlan == null
                        ? null
                        : TextButton(
                            onPressed: onOpenPlan,
                            child: const Text('Open Plan'),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (overview.focusItems.isEmpty)
                    EmptyState(
                      title: 'Your focus is clear',
                      message: overview.openTaskCount == 0
                          ? 'Add tasks in Notes or create a project in Plan when something needs your attention.'
                          : 'Add deadlines or priorities in Plan to help JotCue surface what matters first.',
                      actionLabel: onOpenPlan == null ? null : 'Open Plan',
                      onAction: onOpenPlan,
                      icon: Icons.wb_sunny_outlined,
                    )
                  else
                    ...overview.focusItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _FocusCard(
                          item: item,
                          now: currentTime,
                          onTap: () =>
                              _editTask(context, ref, item.task, projects),
                        ),
                      ),
                    ),
                  if (overview.cues.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(
                      title: 'Needs attention',
                      subtitle: 'Small planning gaps worth resolving.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...overview.cues.map(
                      (cue) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _AttentionCue(cue: cue),
                      ),
                    ),
                  ],
                  if (overview.upcomingProjects.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(
                      title: 'Upcoming project deadlines',
                      subtitle: 'Active projects due within the next 14 days.',
                      trailing: onOpenPlan == null
                          ? null
                          : TextButton(
                              onPressed: onOpenPlan,
                              child: const Text('Review'),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...overview.upcomingProjects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _ProjectDeadlineRow(
                          project: project,
                          now: currentTime,
                          onTap: onOpenPlan,
                        ),
                      ),
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
}

class _PulseHeader extends StatelessWidget {
  const _PulseHeader({
    required this.now,
    required this.displayName,
    required this.onOpenPlan,
  });

  final DateTime now;
  final String? displayName;
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final name = _firstName(displayName);
    final greeting = _greeting(now.hour);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? greeting : '$greeting, $name',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onOpenPlan != null) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            onPressed: onOpenPlan,
            tooltip: 'Open Plan',
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ],
    );
  }
}

class _DaySnapshot extends StatelessWidget {
  const _DaySnapshot({required this.overview});

  final PulseOverview overview;

  @override
  Widget build(BuildContext context) {
    final effort = overview.focusEstimatedMinutes;
    final effortLabel = effort == 0 ? 'Not estimated' : _formatMinutes(effort);

    return AppCard(
      color: AppColors.lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 24),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Your day at a glance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = <Widget>[
                _SnapshotMetric(
                  value: '${overview.focusItems.length}',
                  label: 'Focus',
                ),
                _SnapshotMetric(
                  value: '${overview.dueTodayCount}',
                  label: 'Due today',
                ),
                _SnapshotMetric(value: effortLabel, label: 'Known effort'),
              ];
              if (constraints.maxWidth >= 520) {
                return Row(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      Expanded(child: items[index]),
                      if (index != items.length - 1)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: items
                    .map((item) => SizedBox(width: 108, child: item))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final PulseFocusItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final project = item.project;
    final urgent = task.dueAt?.isBefore(now) ?? false;

    return AppCard(
      onTap: onTap,
      borderColor: urgent
          ? AppColors.primary
          : AppColors.panelBorderFor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: urgent ? AppColors.primarySoft : AppColors.butter,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              urgent ? Icons.priority_high_rounded : Icons.checklist_rounded,
              color: AppColors.ink,
              size: 21,
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.reason,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (project != null || task.estimatedMinutes != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (project != null)
                        _MetaPill(
                          icon: Icons.folder_outlined,
                          label: project.name,
                        ),
                      if (task.estimatedMinutes != null)
                        _MetaPill(
                          icon: Icons.timelapse_rounded,
                          label: _formatMinutes(task.estimatedMinutes!),
                        ),
                      if (task.priority != PriorityLevel.none)
                        _MetaPill(
                          icon: Icons.flag_outlined,
                          label: _priorityLabel(task.priority),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCue extends StatelessWidget {
  const _AttentionCue({required this.cue});

  final PulseCue cue;

  @override
  Widget build(BuildContext context) {
    final icon = switch (cue.kind) {
      PulseCueKind.overdue => Icons.warning_amber_rounded,
      PulseCueKind.deadline => Icons.event_busy_outlined,
      PulseCueKind.unplanned => Icons.calendar_today_outlined,
    };
    final color = switch (cue.kind) {
      PulseCueKind.overdue => AppColors.peach,
      PulseCueKind.deadline => AppColors.butter,
      PulseCueKind.unplanned => AppColors.sky,
    };

    return AppCard(
      color: color,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cue.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(cue.message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDeadlineRow extends StatelessWidget {
  const _ProjectDeadlineRow({
    required this.project,
    required this.now,
    required this.onTap,
  });

  final Project project;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final deadline = project.deadline!;
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    final days = deadlineDay.difference(today).inDays;
    final when = switch (days) {
      < 0 => 'Overdue',
      0 => 'Today',
      1 => 'Tomorrow',
      _ => 'In $days days',
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.folder_open_rounded, size: 21),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$when · ${_shortDate(deadline)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.sky,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 20),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Pulse is using local planning data. Project sync will retry automatically.',
            ),
          ),
        ],
      ),
    );
  }
}

String? _firstName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed.split(RegExp(r'\s+')).first;
}

String _greeting(int hour) {
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

String _weekday(int weekday) {
  return const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];
}

String _month(int month) {
  return const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}

String _shortDate(DateTime date) {
  return '${_month(date.month).substring(0, 3)} ${date.day}';
}

String _formatMinutes(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
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
