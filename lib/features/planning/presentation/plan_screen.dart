import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/models/priority_level.dart';
import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/adaptive_shell.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../automation/models/automation_audit_entry.dart';
import '../../automation/models/automation_preferences.dart';
import '../../automation/models/automation_safety_preferences.dart';
import '../../automation/presentation/automation_activity_section.dart';
import '../../automation/presentation/automation_safety_sheet.dart';
import '../../automation/providers/automation_providers.dart';
import '../../automation/providers/trusted_automation_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../personal_graph/providers/personal_graph_providers.dart';
import '../../projects/models/project.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/schedule_block_sync_conflict.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_proposal.dart';
import '../../scheduling/presentation/widgets/adaptive_replanning_section.dart';
import '../../scheduling/presentation/widgets/scheduling_preferences_sheet.dart';
import '../../scheduling/presentation/widgets/schedule_sync_conflicts_section.dart';
import '../../scheduling/presentation/widgets/suggested_schedule_section.dart';
import '../../scheduling/providers/replanning_providers.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../settings/models/user_settings.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_action_cue.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/plan_overview.dart';
import '../providers/planning_providers.dart';
import 'widgets/project_edit_sheet.dart';
import 'widgets/task_planning_sheet.dart';

enum _LinkedBlockRemovalChoice { keepCalendar, removeBoth }

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key, this.embedded = false, this.now});

  final bool embedded;
  final DateTime? now;

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
    final scheduleSyncConflicts = ref.watch(scheduleBlockSyncConflictsProvider);
    final replanningAsync = ref.watch(
      adaptiveReplanningProvider(replanningNow),
    );
    final automationPreferences = ref.watch(automationPreferencesProvider);
    final automationActivity = ref.watch(automationAuditStreamProvider);
    final automationEntries =
        automationActivity.asData?.value ?? const <AutomationAuditEntry>[];
    final automationSafety =
        ref.watch(automationSafetyPreferencesProvider).asData?.value ??
        const AutomationSafetyPreferences();
    final trustedEnabled =
        automationPreferences.level == AutomationLevel.trusted;
    final trustedSweepProvider = trustedAutomationSweepProvider(replanningNow);
    ref.listen<AsyncValue<AutomationAuditEntry?>>(trustedSweepProvider, (
      previous,
      next,
    ) {
      final entry = next.asData?.value;
      if (entry == null || previous?.asData?.value?.id == entry.id) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref.invalidate(adaptiveReplanningProvider(replanningNow));
        ref.invalidate(schedulingDayProvider(planningDate));
        ref.invalidate(
          schedulingDayProvider(
            DateTime(
              entry.toStartsAt.year,
              entry.toStartsAt.month,
              entry.toStartsAt.day,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trusted JotCue moved “${entry.title}” locally and recorded the change.',
            ),
          ),
        );
      });
    });
    ref.watch(trustedSweepProvider);

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
                  if (scheduleSyncConflicts.asData?.value.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: AppSpacing.xl),
                    ScheduleSyncConflictsSection(
                      state: scheduleSyncConflicts,
                      onDismiss: (conflict) =>
                          _dismissScheduleSyncConflict(context, ref, conflict),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AdaptiveReplanningSection(
                    state: replanningAsync,
                    onMove: (issue) => _moveReplanningBlock(
                      context,
                      ref,
                      replanningNow,
                      issue,
                    ),
                    onMarkCompleted: (block) => _setScheduleBlockStatus(
                      context,
                      ref,
                      replanningNow,
                      block,
                      ScheduleBlockStatus.completed,
                    ),
                    onMarkMissed: (block) => _setScheduleBlockStatus(
                      context,
                      ref,
                      replanningNow,
                      block,
                      ScheduleBlockStatus.skipped,
                    ),
                    onRemove: (block) => _removeScheduleBlock(
                      context,
                      ref,
                      planningDate,
                      block,
                      replanningNow: replanningNow,
                    ),
                    onReviewTask: (taskId) => _reviewTaskById(
                      context,
                      ref,
                      taskId,
                      tasks,
                      overview.projects,
                    ),
                  ),
                  if (replanningAsync.asData?.value.needsAttention == true)
                    const SizedBox(height: AppSpacing.xl),
                  AutomationActivitySection(
                    state: automationActivity,
                    safety: automationSafety,
                    trustedEnabled: trustedEnabled,
                    onTogglePaused: (paused) =>
                        _setTrustedAutomationPaused(context, ref, paused),
                    onManageSafety: () =>
                        _editAutomationSafety(context, ref, tasks, projects),
                    onUndo: (entry) =>
                        _undoTrustedMove(context, ref, replanningNow, entry),
                    onClearOlderActivity: () => _clearOlderAutomationActivity(
                      context,
                      ref,
                      replanningNow,
                    ),
                  ),
                  if (automationEntries.isNotEmpty || trustedEnabled)
                    const SizedBox(height: AppSpacing.xl),
                  SuggestedScheduleSection(
                    state: scheduleAsync,
                    onConfigure: () => _configureAvailability(context, ref),
                    onRequestCalendar: () =>
                        _requestCalendarAccess(context, ref, planningDate),
                    onAccept: (proposal) => _acceptProposal(
                      context,
                      ref,
                      planningDate,
                      proposal,
                      replanningNow: replanningNow,
                    ),
                    onRemoveBlock: (block) => _removeScheduleBlock(
                      context,
                      ref,
                      planningDate,
                      block,
                      replanningNow: replanningNow,
                    ),
                    calendarWriteSupported: ref
                        .watch(deviceScheduleCalendarServiceProvider)
                        .isSupported,
                    onCalendarLinked: (block) => ref
                        .read(deviceScheduleCalendarServiceProvider)
                        .isLinked(block.id),
                    onAddOrUpdateCalendar: (block) =>
                        _addOrUpdateScheduleCalendar(context, ref, block),
                    onRemoveCalendar: (block) =>
                        _removeScheduleCalendar(context, ref, block),
                    wasMovedByJotCue: (block) =>
                        _wasMovedByJotCue(block, automationEntries),
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
                          actionCue: dependencyAnalysis.cueForProject(
                            project.id,
                          ),
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
                              actionCue: dependencyAnalysis.cueForTask(task.id),
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

  Future<void> _setTrustedAutomationPaused(
    BuildContext context,
    WidgetRef ref,
    bool paused,
  ) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }
    try {
      final store = ref.read(offlineAutomationSafetyStoreProvider);
      final current = await store.readPreferences(user.uid);
      await store.writePreferences(user.uid, current.copyWith(paused: paused));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paused
                ? 'Trusted schedule moves are paused on this device.'
                : 'Trusted schedule moves are active again on this device.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update automation safety: $error')),
      );
    }
  }

  Future<void> _editAutomationSafety(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    List<Project> projects,
  ) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }
    try {
      final store = ref.read(offlineAutomationSafetyStoreProvider);
      final current = await store.readPreferences(user.uid);
      if (!context.mounted) {
        return;
      }
      final updated = await showAutomationSafetySheet(
        context: context,
        initial: current,
        tasks: tasks,
        projects: projects,
      );
      if (updated == null) {
        return;
      }
      await store.writePreferences(user.uid, updated);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save automation safety: $error')),
      );
    }
  }

  Future<void> _undoTrustedMove(
    BuildContext context,
    WidgetRef ref,
    DateTime replanningNow,
    AutomationAuditEntry entry,
  ) async {
    try {
      await ref
          .read(trustedScheduleUndoServiceProvider)
          .undo(userId: entry.userId, entry: entry, now: replanningNow);
      ref.invalidate(adaptiveReplanningProvider(replanningNow));
      ref.invalidate(
        schedulingDayProvider(
          DateTime(
            entry.fromStartsAt.year,
            entry.fromStartsAt.month,
            entry.fromStartsAt.day,
          ),
        ),
      );
      ref.invalidate(
        schedulingDayProvider(
          DateTime(
            entry.toStartsAt.year,
            entry.toStartsAt.month,
            entry.toStartsAt.day,
          ),
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored “${entry.title}” to its earlier slot.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not undo trusted move: $error')),
      );
    }
  }

  Future<void> _clearOlderAutomationActivity(
    BuildContext context,
    WidgetRef ref,
    DateTime now,
  ) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear older automation activity?'),
        content: const Text(
          'This removes older device-local audit entries. In-progress records and recent moves or undos inside the 30-minute safety window are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear older'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final removed = await ref
          .read(offlineAutomationAuditStoreProvider)
          .clearOlderEntries(user.uid, now: now);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed == 0
                ? 'No older automation activity was safe to clear.'
                : 'Cleared $removed older automation entr${removed == 1 ? 'y' : 'ies'}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear automation activity: $error')),
      );
    }
  }

  bool _wasMovedByJotCue(
    ScheduleBlock block,
    List<AutomationAuditEntry> entries,
  ) {
    for (final entry in entries) {
      if (entry.blockId != block.id) {
        continue;
      }
      if (entry.status == AutomationAuditStatus.succeeded ||
          entry.status == AutomationAuditStatus.undoPending) {
        return block.startsAt == entry.toStartsAt &&
            block.endsAt == entry.toEndsAt;
      }
      if (entry.status == AutomationAuditStatus.undone) {
        return false;
      }
    }
    return false;
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
    ScheduleProposal proposal, {
    DateTime? replanningNow,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }
    try {
      await ref
          .read(scheduleBlocksRepositoryProvider)
          .acceptProposal(userId: user.uid, proposal: proposal);
      ref.invalidate(schedulingDayProvider(date));
      ref.invalidate(
        adaptiveReplanningProvider(replanningNow ?? DateTime.now()),
      );
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
    ScheduleBlock block, {
    DateTime? replanningNow,
  }) async {
    try {
      final calendar = ref.read(deviceScheduleCalendarServiceProvider);
      if (calendar.isSupported && await calendar.isLinked(block.id)) {
        if (!context.mounted) return;
        final choice = await showDialog<_LinkedBlockRemovalChoice>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove planned block?'),
            content: const Text(
              'This block also has a JotCue-linked device calendar entry. You can keep that calendar event as a normal standalone event, or remove both copies.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_LinkedBlockRemovalChoice.keepCalendar),
                child: const Text('Keep calendar event'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_LinkedBlockRemovalChoice.removeBoth),
                child: const Text('Remove both'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        if (choice == _LinkedBlockRemovalChoice.removeBoth) {
          if (!context.mounted) return;
          final granted = await _ensureScheduleCalendarWriteAccess(
            context,
            ref,
          );
          if (!granted) return;
          await calendar.removeLinkedBlock(block.id);
        } else {
          await calendar.detachBlock(block.id);
        }
      }

      await ref
          .read(scheduleBlocksRepositoryProvider)
          .deleteBlock(block.userId, block.id);
      ref.invalidate(schedulingDayProvider(date));
      ref.invalidate(
        adaptiveReplanningProvider(replanningNow ?? DateTime.now()),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove planned block: $error')),
      );
    }
  }

  Future<bool> _addOrUpdateScheduleCalendar(
    BuildContext context,
    WidgetRef ref,
    ScheduleBlock block,
  ) async {
    final calendar = ref.read(deviceScheduleCalendarServiceProvider);
    if (!calendar.isSupported) return false;
    try {
      final linked = await calendar.isLinked(block.id);
      if (!context.mounted) return false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(linked ? 'Update calendar entry?' : 'Add to calendar?'),
          content: Text(
            linked
                ? 'Update the JotCue-linked calendar event to match this planned block? Only that linked event will be changed.'
                : 'Add this JotCue planning block to a device calendar you choose? JotCue will write one event only after calendar permission is granted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(linked ? 'Update' : 'Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;
      if (!context.mounted) return false;
      final granted = await _ensureScheduleCalendarWriteAccess(context, ref);
      if (!granted) return false;
      await calendar.upsertBlock(block);
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            linked
                ? 'Calendar entry updated.'
                : 'Planned block added to your calendar.',
          ),
        ),
      );
      return true;
    } on PlatformException catch (error) {
      if (error.code == 'CALENDAR_CANCELLED') return false;
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update calendar: ${error.message ?? error.code}',
          ),
        ),
      );
      return false;
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update calendar: $error')),
      );
      return false;
    }
  }

  Future<bool> _removeScheduleCalendar(
    BuildContext context,
    WidgetRef ref,
    ScheduleBlock block,
  ) async {
    final calendar = ref.read(deviceScheduleCalendarServiceProvider);
    if (!calendar.isSupported) return false;
    try {
      final linked = await calendar.isLinked(block.id);
      if (!linked) return true;
      if (!context.mounted) return false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove calendar entry?'),
          content: const Text(
            'This removes only the device calendar event JotCue created for this planning block. The JotCue block itself stays in Plan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;
      if (!context.mounted) return false;
      final granted = await _ensureScheduleCalendarWriteAccess(context, ref);
      if (!granted) return false;
      await calendar.removeLinkedBlock(block.id);
      if (!context.mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Calendar entry removed.')));
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove calendar entry: $error')),
      );
      return false;
    }
  }

  Future<bool> _ensureScheduleCalendarWriteAccess(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final calendar = ref.read(deviceScheduleCalendarServiceProvider);
    if (await calendar.hasWriteAccess()) return true;
    final granted = await calendar.requestWriteAccess();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calendar write access was not granted. JotCue did not change your calendar.',
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _dismissScheduleSyncConflict(
    BuildContext context,
    WidgetRef ref,
    ScheduleBlockSyncConflict conflict,
  ) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return;
    try {
      await ref
          .read(offlineScheduleBlockStoreProvider)
          .dismissConflict(user.uid, conflict.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear sync review: $error')),
      );
    }
  }

  Future<void> _setScheduleBlockStatus(
    BuildContext context,
    WidgetRef ref,
    DateTime replanningNow,
    ScheduleBlock block,
    ScheduleBlockStatus status,
  ) async {
    try {
      await ref
          .read(scheduleBlocksRepositoryProvider)
          .updateStatus(block: block, status: status);
      ref.invalidate(
        schedulingDayProvider(
          DateTime(replanningNow.year, replanningNow.month, replanningNow.day),
        ),
      );
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

  Future<void> _moveReplanningBlock(
    BuildContext context,
    WidgetRef ref,
    DateTime replanningNow,
    ReplanningIssue issue,
  ) async {
    final block = issue.block;
    final suggestion = issue.suggestion;
    if (block == null || suggestion == null) {
      return;
    }
    try {
      final movedBlock = await ref
          .read(scheduleBlocksRepositoryProvider)
          .rescheduleBlock(
            block: block,
            startsAt: suggestion.startsAt,
            endsAt: suggestion.endsAt,
          );
      ref.invalidate(adaptiveReplanningProvider(replanningNow));
      ref.invalidate(
        schedulingDayProvider(
          DateTime(replanningNow.year, replanningNow.month, replanningNow.day),
        ),
      );
      ref.invalidate(
        schedulingDayProvider(
          DateTime(
            suggestion.startsAt.year,
            suggestion.startsAt.month,
            suggestion.startsAt.day,
          ),
        ),
      );
      final calendar = ref.read(deviceScheduleCalendarServiceProvider);
      if (calendar.isSupported && await calendar.isLinked(block.id)) {
        if (!context.mounted) return;
        final updateCalendar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update calendar copy?'),
            content: const Text(
              'This planned block has a linked device calendar event. Update that event to the new time too?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Update calendar'),
              ),
            ],
          ),
        );
        if (updateCalendar == true) {
          if (!context.mounted) return;
          final granted = await _ensureScheduleCalendarWriteAccess(
            context,
            ref,
          );
          if (granted) await calendar.upsertBlock(movedBlock);
        }
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not move planned block: $error')),
      );
    }
  }

  Future<void> _reviewTaskById(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    List<Task> tasks,
    List<Project> projects,
  ) async {
    Task? task;
    for (final item in tasks) {
      if (item.id == taskId) {
        task = item;
        break;
      }
    }
    if (task == null) {
      return;
    }
    await _editTask(context, ref, task, projects);
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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
    required this.actionCue,
    required this.onTap,
  });

  final Project project;
  final PlanOverview overview;
  final ProjectActionCue? actionCue;
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
          if (actionCue?.nextTask != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _MetaLabel(
              icon: Icons.play_arrow_rounded,
              label: 'Next: ${actionCue!.nextTask!.title}',
            ),
          ] else if ((actionCue?.blockedCount ?? 0) > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _MetaLabel(
              icon: Icons.block_rounded,
              label: '${actionCue!.blockedCount} blocked',
            ),
          ],
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
    required this.actionCue,
    required this.onTap,
  });

  final Task task;
  final List<Project> projects;
  final DateTime now;
  final TaskActionCue? actionCue;
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
                    if (actionCue != null && !task.isCompleted)
                      Text(
                        actionCue!.shortLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: actionCue!.isBlocked
                              ? FontWeight.w700
                              : null,
                          color: actionCue!.isBlocked
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
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
