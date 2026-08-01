import 'package:flutter/material.dart';

import '../../../../core/services/app_theme.dart';
import '../../../../core/widgets/pulse_components.dart';

class PastelNoteCard extends StatelessWidget {
  const PastelNoteCard({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.highlighted = false,
  });

  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: highlighted ? 0.13 : 0.06),
            blurRadius: highlighted ? 20 : 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: AppCard(
        color: color,
        borderColor: highlighted ? AppColors.primary : Colors.transparent,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

enum ReminderVisualState { suggested, scheduled, missed, completed }

class ReminderSuggestionChip extends StatelessWidget {
  const ReminderSuggestionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: loading ? 'Creating...' : label,
      icon: loading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
      color: AppColors.butter,
      onTap: loading ? null : onTap,
    );
  }
}

class ReminderStatusChip extends StatelessWidget {
  const ReminderStatusChip({
    super.key,
    required this.label,
    required this.state,
  });

  final String label;
  final ReminderVisualState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      ReminderVisualState.suggested => (
        Icons.auto_awesome_rounded,
        AppColors.butter,
      ),
      ReminderVisualState.scheduled => (
        Icons.notifications_active_rounded,
        AppColors.sky,
      ),
      ReminderVisualState.missed => (
        Icons.warning_amber_rounded,
        AppColors.peach,
      ),
      ReminderVisualState.completed => (
        Icons.check_circle_outline_rounded,
        AppColors.mint,
      ),
    };
    return AppChip(label: label, icon: icon, color: color);
  }
}

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.text,
    required this.completed,
    required this.onToggle,
    this.onLongPress,
    this.reminderState,
    this.reminderLabel,
    this.suggestionLabel,
    this.onSuggestionTap,
  });

  final String text;
  final bool completed;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final ReminderVisualState? reminderState;
  final String? reminderLabel;
  final String? suggestionLabel;
  final VoidCallback? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: completed ? 0.58 : 1,
      child: Material(
        color: completed
            ? AppColors.surface.withValues(alpha: 0.45)
            : AppColors.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: completed,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.isEmpty ? 'Untitled task' : text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                decoration: completed
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationThickness: 1.5,
                              ),
                        ),
                        if (reminderState != null && reminderLabel != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ReminderStatusChip(
                            label: reminderLabel!,
                            state: reminderState!,
                          ),
                        ] else if (suggestionLabel != null &&
                            onSuggestionTap != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ReminderSuggestionChip(
                            label: suggestionLabel!,
                            onTap: onSuggestionTap!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum TaskAction { reminder, delete }

class TaskActionsBottomSheet extends StatelessWidget {
  const TaskActionsBottomSheet({super.key, required this.hasReminder});

  final bool hasReminder;

  static Future<TaskAction?> show(
    BuildContext context, {
    required bool hasReminder,
  }) {
    return showModalBottomSheet<TaskAction>(
      context: context,
      builder: (_) => TaskActionsBottomSheet(hasReminder: hasReminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader(
              title: 'Task actions',
              subtitle: 'Keep this task connected to its note.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.sky,
                      child: Icon(Icons.notifications_outlined),
                    ),
                    title: Text(hasReminder ? 'Edit reminder' : 'Add reminder'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(TaskAction.reminder),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.peach,
                      child: Icon(Icons.delete_outline_rounded),
                    ),
                    title: const Text('Delete task'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(TaskAction.delete),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
