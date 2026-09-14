import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/priority_level.dart';
import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/adaptive_shell.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../assistant/models/ai_assistant_preferences.dart';
import '../../assistant/models/ask_jotcue.dart';
import '../../assistant/providers/assistant_providers.dart';
import '../../assistant/presentation/ask_jotcue_sheet.dart';
import '../../capture/presentation/natural_language_capture_sheet.dart';
import '../../planning/presentation/widgets/task_planning_sheet.dart';
import '../../planning/providers/planning_providers.dart';
import '../../personal_graph/providers/personal_graph_providers.dart';
import '../../projects/models/project.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/scheduling_day_state.dart';
import '../../scheduling/providers/replanning_providers.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/daily_pulse_loop.dart';
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
    final dependencyAnalysis = ref.watch(taskDependencyAnalysisProvider);
    final currentTime = now ?? DateTime.now();
    final replanningNow = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      currentTime.hour,
      currentTime.minute,
    );
    final overview = PulseOverview.build(
      projects: projects,
      tasks: tasks,
      now: currentTime,
      dependencyAnalysis: dependencyAnalysis,
    );
    final planningDate = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final scheduleAsync = ref.watch(schedulingDayProvider(planningDate));
    final replanningAsync = ref.watch(
      adaptiveReplanningProvider(replanningNow),
    );
    final scheduleBlocksAsync = ref.watch(scheduleBlocksStreamProvider);
    final dailyLoop = DailyPulseLoop.build(
      now: currentTime,
      pulse: overview,
      blocks: scheduleBlocksAsync.asData?.value ?? const <ScheduleBlock>[],
      scheduling: scheduleAsync.asData?.value,
      replanning: replanningAsync.asData?.value,
    );
    final aiPreferences =
        ref.watch(aiAssistantPreferencesProvider).asData?.value ??
        const AiAssistantPreferences();
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
                    onAsk: () {
                      final userId = Firebase.apps.isEmpty
                          ? null
                          : ref.read(firebaseAuthProvider).currentUser?.uid;
                      showAskJotCueSheet(
                        context: context,
                        aiPreferences: aiPreferences,
                        gatewayConfigured: ref
                            .read(aiGatewayClientProvider)
                            .isConfigured,
                        assistantContext: AskJotCueContext(
                          now: currentTime,
                          userId: userId,
                          pulse: overview,
                          dailyLoop: dailyLoop,
                          tasks: tasks,
                          projects: projects,
                          blocks:
                              scheduleBlocksAsync.asData?.value ??
                              const <ScheduleBlock>[],
                          scheduling: scheduleAsync.asData?.value,
                          replanning: replanningAsync.asData?.value,
                        ),
                      );
                    },
                    onCapture: () =>
                        showNaturalLanguageCaptureSheet(context: context),
                    onOpenPlan: onOpenPlan,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DaySnapshot(
                    overview: overview,
                    loop: dailyLoop,
                    now: currentTime,
                  ),
                  _PulseCapacity(state: scheduleAsync, onOpenPlan: onOpenPlan),
                  _PulseReplanningNotice(
                    state: replanningAsync,
                    onOpenPlan: onOpenPlan,
                  ),
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
                  if (dailyLoop.shouldShowClosing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _DailyClosing(
                      loop: dailyLoop,
                      onOpenPlan: onOpenPlan,
                      onMarkCompleted: (block) => _setScheduleBlockStatus(
                        context,
                        ref,
                        replanningNow,
                        planningDate,
                        block,
                        ScheduleBlockStatus.completed,
                      ),
                      onMarkMissed: (block) => _setScheduleBlockStatus(
                        context,
                        ref,
                        replanningNow,
                        planningDate,
                        block,
                        ScheduleBlockStatus.skipped,
                      ),
                    ),
                  ],
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
      relatedContext: ref.read(taskGraphContextProvider(task.id)),
      availableTasks: ref.read(tasksProvider),
      actionCue: ref.read(taskActionCueProvider(task.id)),
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

  Future<void> _setScheduleBlockStatus(
    BuildContext context,
    WidgetRef ref,
    DateTime replanningNow,
    DateTime planningDate,
    ScheduleBlock block,
    ScheduleBlockStatus status,
  ) async {
    try {
      await ref
          .read(scheduleBlocksRepositoryProvider)
          .updateStatus(block: block, status: status);
      ref.invalidate(schedulingDayProvider(planningDate));
      ref.invalidate(adaptiveReplanningProvider(replanningNow));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update planned block: $error')),
      );
    }
  }
}

class _PulseHeader extends StatelessWidget {
  const _PulseHeader({
    required this.now,
    required this.displayName,
    required this.onAsk,
    required this.onCapture,
    required this.onOpenPlan,
  });

  final DateTime now;
  final String? displayName;
  final VoidCallback onAsk;
  final VoidCallback onCapture;
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
        const SizedBox(width: AppSpacing.xs),
        IconButton.filledTonal(
          key: const ValueKey('pulse-ask-jotcue'),
          onPressed: onAsk,
          tooltip: 'Ask JotCue',
          icon: const Icon(Icons.auto_awesome_rounded),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton.filledTonal(
          key: const ValueKey('pulse-quick-capture'),
          onPressed: onCapture,
          tooltip: 'Quick capture',
          icon: const Icon(Icons.add_task_rounded),
        ),
        if (onOpenPlan != null) ...[
          const SizedBox(width: AppSpacing.xs),
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

class _PulseCapacity extends StatelessWidget {
  const _PulseCapacity({required this.state, required this.onOpenPlan});

  final AsyncValue<SchedulingDayState> state;
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final data = state.asData?.value;
    if (data == null || !data.isConfigured || !data.isEnabledDay) {
      return const SizedBox.shrink();
    }

    if (data.needsCalendarAccess) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: AppCard(
          color: AppColors.sky,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 19),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(
                child: Text(
                  'Connect your calendar in Plan before JotCue suggests times around fixed commitments.',
                ),
              ),
              if (onOpenPlan != null)
                TextButton(onPressed: onOpenPlan, child: const Text('Plan')),
            ],
          ),
        ),
      );
    }

    final availability = data.availability;
    if (availability == null) {
      return const SizedBox.shrink();
    }
    final proposal = data.proposal;
    final accepted =
        proposal?.acceptedMinutes ??
        data.acceptedBlocks.fold<int>(
          0,
          (sum, block) => sum + block.duration.inMinutes,
        );
    final proposed = proposal?.proposedMinutes ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.calendar_view_day_outlined, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatMinutes(availability.freeMinutes)} realistically free today',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatMinutes(proposed)} suggested · ${_formatMinutes(accepted)} planned/done'
                    '${proposal != null && proposal.unscheduledTaskCount > 0 ? ' · ${proposal.unscheduledTaskCount} ${proposal.unscheduledTaskCount == 1 ? 'task' : 'tasks'} still do not fit' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onOpenPlan != null)
              IconButton(
                onPressed: onOpenPlan,
                tooltip: 'Open Plan',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulseReplanningNotice extends StatelessWidget {
  const _PulseReplanningNotice({required this.state, required this.onOpenPlan});

  final AsyncValue<ReplanningOverview> state;
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final overview = state.asData?.value;
    if (overview == null || !overview.needsAttention) {
      return const SizedBox.shrink();
    }

    final count = overview.issues.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        color: AppColors.butter,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.update_rounded, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'schedule item needs' : 'schedule items need'} review',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'JotCue noticed a missed block, changed availability, calendar conflict, or deadline-capacity problem.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onOpenPlan != null)
              IconButton(
                onPressed: onOpenPlan,
                tooltip: 'Review in Plan',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _DaySnapshot extends StatelessWidget {
  const _DaySnapshot({
    required this.overview,
    required this.loop,
    required this.now,
  });

  final PulseOverview overview;
  final DailyPulseLoop loop;
  final DateTime now;

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
                  now.hour < 12 ? 'Morning Pulse' : "Today's Pulse",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Your day at a glance',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (loop.upNextBlock != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _UpNextLine(block: loop.upNextBlock!, now: now),
          ],
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

class _UpNextLine extends StatelessWidget {
  const _UpNextLine({required this.block, required this.now});

  final ScheduleBlock block;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isActive = !block.startsAt.isAfter(now) && block.endsAt.isAfter(now);
    final label = isActive ? 'Now' : 'Up next';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(
            isActive
                ? Icons.play_circle_outline_rounded
                : Icons.schedule_rounded,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$label · ${_formatClock(context, block.startsAt)} · ${block.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyClosing extends StatelessWidget {
  const _DailyClosing({
    required this.loop,
    required this.onOpenPlan,
    required this.onMarkCompleted,
    required this.onMarkMissed,
  });

  final DailyPulseLoop loop;
  final VoidCallback? onOpenPlan;
  final ValueChanged<ScheduleBlock> onMarkCompleted;
  final ValueChanged<ScheduleBlock> onMarkMissed;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('daily-closing-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Daily Closing',
          subtitle: 'Close the loop on today before tomorrow inherits it.',
          trailing: onOpenPlan == null
              ? null
              : TextButton(onPressed: onOpenPlan, child: const Text('Plan')),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          color: AppColors.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = <Widget>[
                    _SnapshotMetric(
                      value: '${loop.completedCount}',
                      label: 'Completed',
                    ),
                    _SnapshotMetric(
                      value: '${loop.missedCount}',
                      label: 'Missed',
                    ),
                    _SnapshotMetric(
                      value: '${loop.unresolvedCount}',
                      label: 'Review',
                    ),
                    _SnapshotMetric(
                      value: _formatMinutes(loop.completedMinutes),
                      label: 'Done time',
                    ),
                  ];
                  if (constraints.maxWidth >= 600) {
                    return Row(
                      children: [
                        for (
                          var index = 0;
                          index < metrics.length;
                          index++
                        ) ...[
                          Expanded(child: metrics[index]),
                          if (index != metrics.length - 1)
                            const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.md,
                    children: metrics
                        .map((metric) => SizedBox(width: 94, child: metric))
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _closingMessage(loop),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (loop.unresolvedPastBlocks.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...loop.unresolvedPastBlocks
                    .take(3)
                    .map(
                      (block) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _ClosingBlockRow(
                          block: block,
                          onCompleted: () => onMarkCompleted(block),
                          onMissed: () => onMarkMissed(block),
                        ),
                      ),
                    ),
                if (loop.unresolvedPastBlocks.length > 3 && onOpenPlan != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onOpenPlan,
                      child: Text(
                        'Review ${loop.unresolvedPastBlocks.length - 3} more in Plan',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClosingBlockRow extends StatelessWidget {
  const _ClosingBlockRow({
    required this.block,
    required this.onCompleted,
    required this.onMissed,
  });

  final ScheduleBlock block;
  final VoidCallback onCompleted;
  final VoidCallback onMissed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 3),
          Text(
            '${_formatClock(context, block.startsAt)}–${_formatClock(context, block.endsAt)} · ${_formatMinutes(block.duration.inMinutes)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.tonal(
                onPressed: onCompleted,
                child: const Text('Completed'),
              ),
              TextButton(onPressed: onMissed, child: const Text('Missed')),
            ],
          ),
        ],
      ),
    );
  }
}

String _closingMessage(DailyPulseLoop loop) {
  if (loop.todayBlocks.isEmpty) {
    return 'Nothing was planned in JotCue today. You can still review open work in Plan before calling it a day.';
  }
  if (loop.unresolvedCount > 0) {
    return '${loop.unresolvedCount} ${loop.unresolvedCount == 1 ? 'past block still needs' : 'past blocks still need'} a decision. Mark the work completed or missed; move it from Plan if it still belongs later.';
  }
  if (loop.upcomingCount > 0) {
    return '${loop.upcomingCount} ${loop.upcomingCount == 1 ? 'planned block remains' : 'planned blocks remain'} today. Completed work already counts toward future scheduling.';
  }
  if (loop.completedCount > 0 && loop.missedCount == 0) {
    return 'Everything you planned in JotCue today has been closed out.';
  }
  return 'Today is accounted for. Review tomorrow in Plan if anything needs a new home.';
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

String _formatClock(BuildContext context, DateTime value) {
  return TimeOfDay.fromDateTime(value).format(context);
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
