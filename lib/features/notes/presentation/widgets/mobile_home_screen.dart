import 'package:flutter/material.dart';

import '../../../../core/services/app_theme.dart';
import '../../../../core/widgets/pulse_components.dart';
import '../../../reminders/models/reminder.dart';
import '../../../reminders/models/repeat_type.dart';
import '../../models/note.dart';
import '../../models/note_color_tag.dart';
import '../../models/note_task.dart';
import '../../utils/task_parser.dart';
import '../../utils/timestamp_formatter.dart';
import 'note_ui.dart';

enum MobileNoteFilter { all, work, personal, ideas, reminders, study, todo }

extension MobileNoteFilterDetails on MobileNoteFilter {
  String get label => switch (this) {
    MobileNoteFilter.all => 'All',
    MobileNoteFilter.work => 'Work',
    MobileNoteFilter.personal => 'Personal',
    MobileNoteFilter.ideas => 'Ideas',
    MobileNoteFilter.reminders => 'Reminders',
    MobileNoteFilter.study => 'Study',
    MobileNoteFilter.todo => 'To-Do',
  };

  IconData get icon => switch (this) {
    MobileNoteFilter.all => Icons.grid_view_rounded,
    MobileNoteFilter.work => Icons.work_outline_rounded,
    MobileNoteFilter.personal => Icons.favorite_border_rounded,
    MobileNoteFilter.ideas => Icons.lightbulb_outline_rounded,
    MobileNoteFilter.reminders => Icons.notifications_none_rounded,
    MobileNoteFilter.study => Icons.school_outlined,
    MobileNoteFilter.todo => Icons.check_box_outlined,
  };

  Color get color => switch (this) {
    MobileNoteFilter.all => AppColors.lavender,
    MobileNoteFilter.work => AppColors.sky,
    MobileNoteFilter.personal => AppColors.blush,
    MobileNoteFilter.ideas => AppColors.mint,
    MobileNoteFilter.reminders => AppColors.peach,
    MobileNoteFilter.study => AppColors.butter,
    MobileNoteFilter.todo => AppColors.mint,
  };
}

class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({
    super.key,
    required this.notes,
    required this.pinnedNotes,
    required this.remindersByNoteId,
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onSearchChanged,
    required this.onOpenNote,
    required this.onTogglePin,
    required this.onManageReminders,
    required this.onDelete,
    required this.onCreate,
    required this.onFilterTap,
    required this.onProfileTap,
    this.profileName,
    this.profilePhotoUrl,
    this.isOnline = true,
    this.emptyTitle = 'No notes yet',
    this.emptyMessage = 'Start by creating your first note.',
    this.emptyActionLabel = 'New Note',
  });

  final List<Note> notes;
  final List<Note> pinnedNotes;
  final Map<String, List<Reminder>> remindersByNoteId;
  final TextEditingController searchController;
  final MobileNoteFilter selectedFilter;
  final ValueChanged<MobileNoteFilter> onFilterSelected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note> onTogglePin;
  final ValueChanged<Note> onManageReminders;
  final ValueChanged<Note> onDelete;
  final VoidCallback? onCreate;
  final VoidCallback onFilterTap;
  final VoidCallback onProfileTap;
  final String? profileName;
  final String? profilePhotoUrl;
  final bool isOnline;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyActionLabel;

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName(profileName);
    final unpinnedNotes = pinnedNotes.isEmpty
        ? notes
        : notes.where((note) => !note.isPinned).toList();

    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.canvasFor(context)),
      child: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          cacheExtent: 700,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MobileHeader(
                      displayName: displayName,
                      photoUrl: profilePhotoUrl,
                      isOnline: isOnline,
                      onProfileTap: onProfileTap,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _MobileSearchRow(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      onFilterTap: onFilterTap,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MobileCategoryChips(
                      selectedFilter: selectedFilter,
                      onSelected: onFilterSelected,
                    ),
                  ],
                ),
              ),
            ),
            if (notes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: emptyTitle,
                  message: emptyMessage,
                  actionLabel: emptyActionLabel,
                  onAction: onCreate,
                ),
              )
            else ...[
              if (pinnedNotes.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PinnedNotesCarousel(
                    notes: pinnedNotes,
                    remindersByNoteId: remindersByNoteId,
                    onOpenNote: onOpenNote,
                    onTogglePin: onTogglePin,
                    onManageReminders: onManageReminders,
                    onDelete: onDelete,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: SectionHeader(
                    title: 'All Notes',
                    subtitle: '${notes.length} sorted by recent updates',
                    trailing: Text(
                      'Sort: Updated',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              if (unpinnedNotes.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      120,
                    ),
                    child: EmptyState(
                      title: 'Only pinned notes here',
                      message: 'Unpin a note to see it in the regular grid.',
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: MobileNotesMasonryGrid(
                    notes: unpinnedNotes,
                    remindersByNoteId: remindersByNoteId,
                    onOpenNote: onOpenNote,
                    onTogglePin: onTogglePin,
                    onManageReminders: onManageReminders,
                    onDelete: onDelete,
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 116)),
          ],
        ),
      ),
    );
  }

  String _displayName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'there';
    }
    return trimmed.split('@').first;
  }
}

class MobileNotesLoading extends StatelessWidget {
  const MobileNotesLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.canvasFor(context)),
      child: Center(
        child: AppCard(
          color: AppColors.butter,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppSpacing.sm),
              Text('Gathering your notes...'),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileNotesError extends StatelessWidget {
  const MobileNotesError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.canvasFor(context)),
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load notes',
        message: '$error',
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.displayName,
    this.photoUrl,
    required this.isOnline,
    required this.onProfileTap,
  });

  final String displayName;
  final String? photoUrl;
  final bool isOnline;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final avatarForeground = AppColors.textFor(AppColors.lavender);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PulseNotes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Good ${_dayPart()}, $displayName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Capture ideas, organize your thoughts, and never miss a thing.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: AppColors.lavender,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onProfileTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: photoUrl == null || photoUrl!.isEmpty
                      ? Center(
                          child: Text(
                            displayName == 'there'
                                ? 'P'
                                : displayName[0].toUpperCase(),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: avatarForeground),
                          ),
                        )
                      : Ink.image(
                          image: NetworkImage(
                            photoUrl!,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                          ),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            if (!isOnline)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.peach,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.canvasFor(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'morning';
    }
    if (hour < 17) {
      return 'afternoon';
    }
    return 'evening';
  }
}

class _MobileSearchRow extends StatelessWidget {
  const _MobileSearchRow({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search notes',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: onFilterTap,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filters',
          ),
        ),
      ],
    );
  }
}

class _MobileCategoryChips extends StatelessWidget {
  const _MobileCategoryChips({
    required this.selectedFilter,
    required this.onSelected,
  });

  final MobileNoteFilter selectedFilter;
  final ValueChanged<MobileNoteFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MobileNoteFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final filter = MobileNoteFilter.values[index];
          return AppChip(
            label: filter.label,
            icon: filter.icon,
            selected: selectedFilter == filter,
            color: filter.color,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _PinnedNotesCarousel extends StatelessWidget {
  const _PinnedNotesCarousel({
    required this.notes,
    required this.remindersByNoteId,
    required this.onOpenNote,
    required this.onTogglePin,
    required this.onManageReminders,
    required this.onDelete,
  });

  final List<Note> notes;
  final Map<String, List<Reminder>> remindersByNoteId;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note> onTogglePin;
  final ValueChanged<Note> onManageReminders;
  final ValueChanged<Note> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SectionHeader(
              title: 'Pinned',
              subtitle: 'Keep these within thumb reach',
              trailing: Text(
                'See all',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 324,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final note = notes[index];
                return SizedBox(
                  width: 250,
                  child: MobileNoteCard(
                    note: note,
                    reminders: remindersByNoteId[note.id] ?? const [],
                    pinnedDisplay: true,
                    onOpenNote: () => onOpenNote(note),
                    onTogglePin: () => onTogglePin(note),
                    onManageReminders: () => onManageReminders(note),
                    onDelete: () => onDelete(note),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MobileNotesMasonryGrid extends StatelessWidget {
  const MobileNotesMasonryGrid({
    super.key,
    required this.notes,
    required this.remindersByNoteId,
    required this.onOpenNote,
    required this.onTogglePin,
    required this.onManageReminders,
    required this.onDelete,
  });

  final List<Note> notes;
  final Map<String, List<Reminder>> remindersByNoteId;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note> onTogglePin;
  final ValueChanged<Note> onManageReminders;
  final ValueChanged<Note> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnsCount = constraints.maxWidth < 380 ? 1 : 2;
        final columns = List.generate(columnsCount, (_) => <Note>[]);
        final columnHeights = List.generate(columnsCount, (_) => 0.0);

        for (final note in notes) {
          var targetColumn = 0;
          for (var index = 1; index < columnHeights.length; index++) {
            if (columnHeights[index] < columnHeights[targetColumn]) {
              targetColumn = index;
            }
          }
          columns[targetColumn].add(note);
          columnHeights[targetColumn] += _estimatedCardHeight(note);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var columnIndex = 0;
                columnIndex < columns.length;
                columnIndex++
              ) ...[
                if (columnIndex > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    children: [
                      for (final note in columns[columnIndex]) ...[
                        MobileNoteCard(
                          note: note,
                          reminders: remindersByNoteId[note.id] ?? const [],
                          onOpenNote: () => onOpenNote(note),
                          onTogglePin: () => onTogglePin(note),
                          onManageReminders: () => onManageReminders(note),
                          onDelete: () => onDelete(note),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _estimatedCardHeight(Note note) {
    final tasks = TaskParser.extractTasks(note.content);
    final titleLength = note.title?.length ?? 0;
    final plainText = TaskParser.extractPlainTextLines(note.content).join(' ');
    final hasImage = note.images.isNotEmpty;
    return 120 +
        (titleLength > 32 ? 20 : 0) +
        (plainText.length > 90
            ? 42
            : plainText.length > 30
            ? 20
            : 0) +
        (hasImage ? 98 : 0) +
        (!hasImage && tasks.isNotEmpty ? 24 + tasks.take(3).length * 22 : 0);
  }
}

enum _MobileNoteAction { pin, reminders, delete }

class MobileNoteCard extends StatelessWidget {
  const MobileNoteCard({
    super.key,
    required this.note,
    required this.reminders,
    required this.onOpenNote,
    required this.onTogglePin,
    required this.onManageReminders,
    required this.onDelete,
    this.pinnedDisplay = false,
  });

  final Note note;
  final List<Reminder> reminders;
  final VoidCallback onOpenNote;
  final VoidCallback onTogglePin;
  final VoidCallback onManageReminders;
  final VoidCallback onDelete;
  final bool pinnedDisplay;

  @override
  Widget build(BuildContext context) {
    final title = note.title?.trim();
    final plainText = TaskParser.extractPlainTextLines(note.content).join(' ');
    final tasks = TaskParser.extractTasks(note.content);
    final activeReminders =
        reminders.where((reminder) => !reminder.isCompleted).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final nextReminder = activeReminders.isEmpty ? null : activeReminders.first;
    final timestamp = note.updatedAt == note.createdAt
        ? note.createdAt
        : note.updatedAt;
    final tag = note.tags.isNotEmpty
        ? note.tags.first
        : NoteColorTag.fromColor(note.color).label;
    final noteColor = Color(note.color);
    final foreground = AppColors.textFor(noteColor);
    final mutedForeground = AppColors.mutedTextFor(noteColor);
    final hasImage = note.images.isNotEmpty;
    final showTaskPreview = !pinnedDisplay && tasks.isNotEmpty && !hasImage;
    final maxHeight = pinnedDisplay ? 316.0 : 330.0;

    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: PastelNoteCard(
          color: noteColor,
          highlighted: false,
          onTap: onOpenNote,
          child: ClipRect(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AppChip(
                        label: tag,
                        icon: note.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.label_outline_rounded,
                        color: Colors.white60,
                      ),
                    ),
                    PopupMenuButton<_MobileNoteAction>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      onSelected: (action) {
                        switch (action) {
                          case _MobileNoteAction.pin:
                            onTogglePin();
                            return;
                          case _MobileNoteAction.reminders:
                            onManageReminders();
                            return;
                          case _MobileNoteAction.delete:
                            onDelete();
                            return;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _MobileNoteAction.pin,
                          child: Text(note.isPinned ? 'Unpin' : 'Pin note'),
                        ),
                        const PopupMenuItem(
                          value: _MobileNoteAction.reminders,
                          child: Text('Reminders'),
                        ),
                        const PopupMenuItem(
                          value: _MobileNoteAction.delete,
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title == null || title.isEmpty
                      ? (plainText.isEmpty ? 'Untitled note' : plainText)
                      : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                if (title != null &&
                    title.isNotEmpty &&
                    plainText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    plainText,
                    maxLines: pinnedDisplay || hasImage || showTaskPreview
                        ? 2
                        : 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedForeground),
                  ),
                ],
                if (hasImage) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: Image.network(
                      note.images.first,
                      width: double.infinity,
                      height: pinnedDisplay ? 76 : 92,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) => SizedBox(
                        height: pinnedDisplay ? 76 : 92,
                        child: const ColoredBox(
                          color: Colors.white38,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (showTaskPreview) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _TaskPreview(
                    tasks: tasks,
                    foreground: foreground,
                    mutedForeground: mutedForeground,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _MobileCardFooter(
                  timestamp: timestamp,
                  reminders: activeReminders,
                  nextReminder: nextReminder,
                  mutedForeground: mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskPreview extends StatelessWidget {
  const _TaskPreview({
    required this.tasks,
    required this.foreground,
    required this.mutedForeground,
  });

  final List<NoteTask> tasks;
  final Color foreground;
  final Color mutedForeground;

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final task in visibleTasks) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                task.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: task.isCompleted ? AppColors.primary : mutedForeground,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  task.text.isEmpty ? 'Untitled task' : task.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: task.isCompleted
                        ? mutedForeground
                        : foreground.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (tasks.length > visibleTasks.length)
          Text(
            '+${tasks.length - visibleTasks.length} more',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: mutedForeground,
            ),
          ),
      ],
    );
  }
}

class _MobileCardFooter extends StatelessWidget {
  const _MobileCardFooter({
    required this.timestamp,
    required this.reminders,
    required this.nextReminder,
    required this.mutedForeground,
  });

  final DateTime timestamp;
  final List<Reminder> reminders;
  final Reminder? nextReminder;
  final Color mutedForeground;

  @override
  Widget build(BuildContext context) {
    if (nextReminder != null) {
      final reminder = nextReminder!;
      return ReminderStatusChip(
        label: _reminderLabel(context, reminder, reminders.length),
        state: reminder.scheduledAt.isBefore(DateTime.now())
            ? ReminderVisualState.missed
            : ReminderVisualState.scheduled,
      );
    }

    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: mutedForeground),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            TimestampFormatter.format(timestamp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _reminderLabel(BuildContext context, Reminder reminder, int count) {
    if (count > 1) {
      return '$count reminders';
    }
    if (reminder.repeat != RepeatType.none) {
      return reminder.repeat.name;
    }
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(reminder.scheduledAt));
  }
}
