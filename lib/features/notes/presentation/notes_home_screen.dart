import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/adaptive_shell.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../../core/services/firebase_providers.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/providers/user_profile_providers.dart';
import '../../reminders/data/smart_reminder_parser.dart';
import '../../reminders/models/parsed_reminder.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/models/repeat_type.dart';
import '../../reminders/presentation/note_reminders_sheet.dart';
import '../../reminders/providers/reminders_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../../../core/services/connectivity_providers.dart';
import '../models/note_color_tag.dart';
import '../models/note.dart';
import '../models/note_category.dart';
import '../models/note_task.dart';
import '../providers/note_draft_controller.dart';
import '../providers/notes_providers.dart';
import '../utils/task_parser.dart';
import '../utils/timestamp_formatter.dart';
import 'widgets/mobile_home_screen.dart';
import 'widgets/note_ui.dart';

class NotesHomeScreen extends ConsumerStatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  ConsumerState<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends ConsumerState<NotesHomeScreen> {
  StreamSubscription<String?>? _notificationSelectionSubscription;
  late final TextEditingController _searchController;
  MobileNoteFilter _homeFilter = MobileNoteFilter.all;
  _DesktopNoteFilter _desktopFilter = _DesktopNoteFilter.all;
  String? _selectedNoteId;
  bool _creatingDesktopNote = false;
  bool _showingDesktopProfile = false;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final notifications = ref.read(localNotificationsServiceProvider);
    _notificationSelectionSubscription = notifications.selectedNoteStream
        .listen((noteId) {
          if (!mounted) {
            return;
          }

          setState(() {
            _selectedNoteId = noteId;
            _creatingDesktopNote = false;
          });
        });
  }

  @override
  void dispose() {
    _notificationSelectionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final allNotes = notesAsync.asData?.value ?? const <Note>[];
    final filteredNotes = ref.watch(filteredNotesProvider);
    final allReminders =
        ref.watch(remindersStreamProvider).asData?.value ?? const <Reminder>[];
    final reminderNoteIds = allReminders
        .where((reminder) => !reminder.isCompleted)
        .map((reminder) => reminder.noteId)
        .toSet();
    final mobileBaseNotes = switch (_navIndex) {
      1 => filteredNotes.where((note) => _isToday(note.updatedAt)).toList(),
      2 =>
        filteredNotes
            .where((note) => reminderNoteIds.contains(note.id))
            .toList(),
      _ => filteredNotes,
    };
    final notes = _filterMobileNotes(
      mobileBaseNotes,
      _homeFilter,
      reminderNoteIds,
    );
    final pinnedNotes = notes.where((note) => note.isPinned).toList();
    final remindersByNoteId = _remindersByNoteId(allReminders);
    final navigationNotes = switch (_navIndex) {
      1 => filteredNotes.where((note) => _isToday(note.updatedAt)).toList(),
      2 =>
        filteredNotes
            .where((note) => reminderNoteIds.contains(note.id))
            .toList(),
      _ => filteredNotes,
    };
    final desktopNotes = navigationNotes.where((note) {
      return switch (_desktopFilter) {
        _DesktopNoteFilter.all => true,
        _DesktopNoteFilter.work => _hasTag(note, 'Work'),
        _DesktopNoteFilter.personal => _hasTag(note, 'Personal'),
        _DesktopNoteFilter.ideas => _hasTag(note, 'Ideas'),
        _DesktopNoteFilter.reminders => reminderNoteIds.contains(note.id),
      };
    }).toList();
    final selectedNote = _noteById(allNotes, _selectedNoteId);
    final allTags = ref.watch(allNoteTagsProvider);
    final filter = ref.watch(notesFilterProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isOnline = ref.watch(isOnlineProvider).asData?.value ?? true;
    final profileName =
        profile?.displayName ??
        user?.displayName ??
        user?.email?.split('@').first;

    if (_searchController.text != filter.searchQuery) {
      _searchController.value = _searchController.value.copyWith(
        text: filter.searchQuery,
        selection: TextSelection.collapsed(offset: filter.searchQuery.length),
        composing: TextRange.empty,
      );
    }

    return AdaptiveShell(
      selectedIndex: _navIndex,
      onCreate: user == null ? null : () => _createNote(context, user),
      onDestinationSelected: _selectDestination,
      profileName: profileName,
      profileSubtitle: user?.email,
      onProfileTap: _openProfile,
      body: notesAsync.when(
        loading: () => const MobileNotesLoading(),
        error: (error, _) => MobileNotesError(
          error: error,
          onRetry: () => ref.invalidate(notesStreamProvider),
        ),
        data: (_) => _navIndex == 3
            ? SettingsScreen(onOpenProfile: _openProfile)
            : MobileHomeScreen(
                notes: notes,
                pinnedNotes: pinnedNotes,
                remindersByNoteId: remindersByNoteId,
                searchController: _searchController,
                selectedFilter: _homeFilter,
                profileName: profileName,
                profilePhotoUrl: profile?.photoUrl ?? user?.photoURL,
                isOnline: isOnline,
                emptyTitle: allNotes.isEmpty && !filter.hasActiveFilters
                    ? 'No notes yet'
                    : filter.searchQuery.trim().isNotEmpty
                    ? 'No search results'
                    : 'No matching notes',
                emptyMessage: allNotes.isEmpty && !filter.hasActiveFilters
                    ? 'Start by creating your first note.'
                    : filter.searchQuery.trim().isNotEmpty
                    ? 'Try a different keyword or clear your filters.'
                    : 'Try adjusting your filters.',
                emptyActionLabel: allNotes.isEmpty && !filter.hasActiveFilters
                    ? 'New Note'
                    : 'Clear filters',
                onCreate: allNotes.isEmpty && !filter.hasActiveFilters
                    ? (user == null
                          ? null
                          : () => _openEditor(context, user: user))
                    : () => ref.read(notesFilterProvider.notifier).clear(),
                onFilterSelected: (selectedFilter) {
                  setState(() {
                    _homeFilter = selectedFilter;
                    if (selectedFilter == MobileNoteFilter.reminders) {
                      _navIndex = 2;
                    } else if (_navIndex == 2) {
                      _navIndex = 0;
                    }
                  });
                },
                onSearchChanged: (value) {
                  ref.read(notesFilterProvider.notifier).setSearchQuery(value);
                },
                onOpenNote: user == null
                    ? (_) {}
                    : (note) => _openEditor(context, user: user, note: note),
                onTogglePin: _togglePin,
                onManageReminders: (note) => _openReminders(context, note),
                onDelete: (note) => _deleteNote(context, note),
                onFilterTap: () => _openMobileFilters(allTags, filter),
                onProfileTap: _openProfile,
              ),
      ),
      desktopList: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DesktopErrorState(error: error),
        data: (_) => _DesktopNotesPanel(
          notes: desktopNotes,
          selectedNoteId: _selectedNoteId,
          searchController: _searchController,
          selectedFilter: _desktopFilter,
          onFilterSelected: (filter) {
            setState(() {
              _desktopFilter = filter;
            });
          },
          onSearchChanged: (value) {
            ref.read(notesFilterProvider.notifier).setSearchQuery(value);
          },
          onCreate: user == null ? null : () => _createDesktopNote(),
          onSelected: (note) {
            setState(() {
              _selectedNoteId = note.id;
              _creatingDesktopNote = false;
            });
          },
        ),
      ),
      desktopEditor: _buildDesktopEditor(
        user: user,
        selectedNote: selectedNote,
      ),
    );
  }

  void _selectDestination(int index) {
    setState(() {
      _navIndex = index;
      _homeFilter = index == 2
          ? MobileNoteFilter.reminders
          : MobileNoteFilter.all;
      if (index == 3) {
        _creatingDesktopNote = false;
        _showingDesktopProfile = false;
      }
    });
  }

  void _createNote(BuildContext context, User user) {
    if (MediaQuery.sizeOf(context).width >= AdaptiveShell.desktopBreakpoint) {
      _createDesktopNote();
      return;
    }
    _openEditor(context, user: user);
  }

  void _createDesktopNote() {
    setState(() {
      _navIndex = 0;
      _homeFilter = MobileNoteFilter.all;
      _desktopFilter = _DesktopNoteFilter.all;
      _selectedNoteId = null;
      _creatingDesktopNote = true;
      _showingDesktopProfile = false;
    });
  }

  Widget _buildDesktopEditor({
    required User? user,
    required Note? selectedNote,
  }) {
    if (_navIndex == 3) {
      if (_showingDesktopProfile) {
        return ProfileScreen(
          embedded: true,
          onClose: () {
            setState(() {
              _showingDesktopProfile = false;
            });
          },
        );
      }
      return SettingsScreen(embedded: true, onOpenProfile: _openProfile);
    }
    if (user == null) {
      return const _DesktopEditorEmptyState();
    }
    if (_creatingDesktopNote) {
      return NoteEditorSheet(
        key: const ValueKey('desktop-new-note'),
        userId: user.uid,
        embedded: true,
        onClose: () {
          setState(() {
            _creatingDesktopNote = false;
          });
        },
      );
    }
    if (selectedNote == null) {
      return const _DesktopEditorEmptyState();
    }
    return NoteEditorSheet(
      key: ValueKey('desktop-note-${selectedNote.id}'),
      userId: user.uid,
      note: selectedNote,
      embedded: true,
      onClose: () {
        setState(() {
          _selectedNoteId = null;
        });
      },
    );
  }

  void _openProfile() {
    if (MediaQuery.sizeOf(context).width >= AdaptiveShell.tabletBreakpoint) {
      setState(() {
        _navIndex = 3;
        _creatingDesktopNote = false;
        _showingDesktopProfile = true;
      });
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
  }

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  bool _hasTag(Note note, String value) {
    return note.tags.any((tag) => tag.toLowerCase() == value.toLowerCase());
  }

  List<Note> _filterMobileNotes(
    List<Note> source,
    MobileNoteFilter selectedFilter,
    Set<String> reminderNoteIds,
  ) {
    return switch (selectedFilter) {
      MobileNoteFilter.all => source,
      MobileNoteFilter.work =>
        source
            .where((note) => _hasTag(note, MobileNoteFilter.work.label))
            .toList(),
      MobileNoteFilter.personal =>
        source
            .where((note) => _hasTag(note, MobileNoteFilter.personal.label))
            .toList(),
      MobileNoteFilter.ideas =>
        source
            .where((note) => _hasTag(note, MobileNoteFilter.ideas.label))
            .toList(),
      MobileNoteFilter.study =>
        source
            .where((note) => _hasTag(note, MobileNoteFilter.study.label))
            .toList(),
      MobileNoteFilter.todo =>
        source
            .where((note) => TaskParser.extractTasks(note.content).isNotEmpty)
            .toList(),
      MobileNoteFilter.reminders =>
        source.where((note) => reminderNoteIds.contains(note.id)).toList(),
    };
  }

  Map<String, List<Reminder>> _remindersByNoteId(List<Reminder> reminders) {
    final grouped = <String, List<Reminder>>{};
    for (final reminder in reminders) {
      grouped.putIfAbsent(reminder.noteId, () => <Reminder>[]).add(reminder);
    }
    return grouped;
  }

  Note? _noteById(List<Note> notes, String? noteId) {
    if (noteId == null) {
      return null;
    }
    for (final note in notes) {
      if (note.id == noteId) {
        return note;
      }
    }
    return null;
  }

  Future<void> _openMobileFilters(
    List<String> allTags,
    NotesFilterState filter,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: SectionHeader(
                    title: 'Filters',
                    subtitle: filter.hasActiveFilters
                        ? 'Refine what appears on your homepage.'
                        : 'Choose tags or note colors.',
                    trailing: filter.hasActiveFilters
                        ? TextButton(
                            onPressed: () {
                              ref.read(notesFilterProvider.notifier).clear();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Clear'),
                          )
                        : null,
                  ),
                ),
                _NotesFilterBar(tags: allTags, filter: filter),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note?'),
          content: const Text('This also deletes linked reminders.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(notesServiceProvider)
          .deleteNote(note.id, userId: note.userId);
      unawaited(
        ref
            .read(remindersServiceProvider)
            .deleteRemindersForNote(userId: note.userId, noteId: note.id)
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint(
                '[NotesHome] event=reminder_cleanup_deferred '
                'noteId=${note.id} error=$error\n$stackTrace',
              );
            }),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Note deleted.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    required User user,
    Note? note,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return NoteEditorSheet(note: note, userId: user.uid);
      },
    );
  }

  Future<void> _openReminders(BuildContext context, Note note) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return NoteRemindersSheet(note: note);
      },
    );
  }

  Future<void> _togglePin(Note note) async {
    await ref
        .read(notesServiceProvider)
        .updateNote(note.copyWith(isPinned: !note.isPinned));
  }
}

enum _DesktopNoteFilter { all, work, personal, ideas, reminders }

enum _EditorMenuAction { saveNow, reminders, close }

extension on _DesktopNoteFilter {
  String get label => switch (this) {
    _DesktopNoteFilter.all => 'All',
    _DesktopNoteFilter.work => 'Work',
    _DesktopNoteFilter.personal => 'Personal',
    _DesktopNoteFilter.ideas => 'Ideas',
    _DesktopNoteFilter.reminders => 'Reminders',
  };
}

class _DesktopNotesPanel extends StatelessWidget {
  const _DesktopNotesPanel({
    required this.notes,
    required this.selectedNoteId,
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onSearchChanged,
    required this.onSelected,
    this.onCreate,
  });

  final List<Note> notes;
  final String? selectedNoteId;
  final TextEditingController searchController;
  final _DesktopNoteFilter selectedFilter;
  final ValueChanged<_DesktopNoteFilter> onFilterSelected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Note> onSelected;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'All Notes',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'New Note (Ctrl+N)',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${notes.length} in this view',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _DesktopNoteFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: AppChip(
                    label: filter.label,
                    selected: selectedFilter == filter,
                    color: switch (filter) {
                      _DesktopNoteFilter.all => AppColors.ink,
                      _DesktopNoteFilter.work => AppColors.butter,
                      _DesktopNoteFilter.personal => AppColors.blush,
                      _DesktopNoteFilter.ideas => AppColors.mint,
                      _DesktopNoteFilter.reminders => AppColors.lavender,
                    },
                    onTap: () => onFilterSelected(filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: notes.isEmpty
                ? EmptyState(
                    title: 'No notes yet',
                    message: 'Create your first PulseNote',
                    actionLabel: 'New Note',
                    onAction: onCreate,
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: notes.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return _DesktopNotePreviewCard(
                        note: note,
                        selected: note.id == selectedNoteId,
                        onTap: () => onSelected(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNotePreviewCard extends StatelessWidget {
  const _DesktopNotePreviewCard({
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = note.title?.trim();
    final plainText = TaskParser.extractPlainTextLines(note.content).join(' ');
    final tasks = TaskParser.extractTasks(note.content);
    final completedTasks = tasks.where((task) => task.isCompleted).length;
    final noteColor = Color(note.color);
    final foreground = AppColors.textFor(noteColor);
    final mutedForeground = AppColors.mutedTextFor(noteColor);
    final timestamp = note.updatedAt == note.createdAt
        ? note.createdAt
        : note.updatedAt;

    return Material(
      color: noteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
          color: selected ? AppColors.selectionBorder : AppColors.panelBorder,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.images.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Image.network(
                    note.images.first,
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 82,
                      height: 82,
                      child: ColoredBox(
                        color: Colors.white38,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title?.isNotEmpty == true
                                ? title!
                                : 'Untitled note',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: foreground),
                          ),
                        ),
                        if (note.isPinned)
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      plainText.isEmpty
                          ? 'A quiet page, ready for words.'
                          : plainText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: mutedForeground),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (tasks.isNotEmpty) ...[
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$completedTasks/${tasks.length}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: mutedForeground),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          TimestampFormatter.format(timestamp),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopEditorEmptyState extends StatelessWidget {
  const _DesktopEditorEmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.edit_note_rounded,
      title: 'Select a note to start editing',
      message: 'Your note will open here without leaving the workspace.',
    );
  }
}

class _DesktopErrorState extends StatelessWidget {
  const _DesktopErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load notes',
      message: '$error',
    );
  }
}

// ignore: unused_element
class _NoteCard extends ConsumerWidget {
  const _NoteCard({
    required this.note,
    required this.isHighlighted,
    required this.onEdit,
    required this.onTogglePin,
    required this.onManageReminders,
    required this.onToggleTask,
    required this.onDeleteTask,
    required this.onDelete,
  });

  final Note note;
  final bool isHighlighted;
  final VoidCallback? onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onManageReminders;
  final Future<void> Function(NoteTask task, bool isCompleted) onToggleTask;
  final Future<void> Function(NoteTask task) onDeleteTask;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteColor = Color(note.color);
    final noteTag = NoteColorTag.fromColor(note.color);
    final title = note.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final tasks = TaskParser.extractTasks(note.content);
    final taskSuggestions = TaskParser.extractTaskReminderSuggestions(
      note.content,
      SmartReminderParser(),
    );
    final plainText = TaskParser.extractPlainTextLines(note.content).join('\n');
    final displayTimestamp = note.updatedAt == note.createdAt
        ? note.createdAt
        : note.updatedAt;
    final reminders =
        ref.watch(noteRemindersStreamProvider(note.id)).asData?.value ??
        const [];
    return RepaintBoundary(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        color: noteColor,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NoteColorBadge(tag: noteTag),
                          const SizedBox(height: AppSpacing.xs),
                          if (note.isPinned) ...[
                            Text(
                              'Pinned',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: noteTag.accent,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          Text(
                            hasTitle
                                ? title
                                : (plainText.isEmpty ? 'Task note' : plainText),
                            maxLines: hasTitle ? 2 : 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (hasTitle && plainText.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              plainText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onTogglePin,
                      icon: Icon(
                        note.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                      ),
                      tooltip: note.isPinned ? 'Unpin' : 'Pin',
                    ),
                    IconButton(
                      onPressed: onManageReminders,
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Reminders',
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                _ReminderSummary(noteId: note.id),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: note.tags.map((tag) {
                      return _NoteTagChip(tag: tag);
                    }).toList(),
                  ),
                ],
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _TaskListView(
                    key: ValueKey(Object.hash(note.id, note.content)),
                    note: note,
                    tasks: tasks,
                    taskSuggestions: taskSuggestions,
                    reminders: reminders,
                    onToggleTask: onToggleTask,
                    onDeleteTask: onDeleteTask,
                  ),
                ],
                if (note.images.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NoteImageGallery(noteId: note.id, images: note.images),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${note.images.length} image(s) attached',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        TimestampFormatter.format(displayTimestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      TimestampFormatter.format(displayTimestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderSummary extends ConsumerWidget {
  const _ReminderSummary({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteRemindersAsync = ref.watch(noteRemindersStreamProvider(noteId));
    final nextReminderAsync = ref.watch(nextReminderForNoteProvider(noteId));
    final reminders = noteRemindersAsync.asData?.value ?? const [];
    final activeCount = reminders.where((item) => !item.isCompleted).length;
    final nextReminder = nextReminderAsync.asData?.value;

    if (activeCount == 0 || nextReminder == null) {
      return Text(
        'No active reminders',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(nextReminder.scheduledAt);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(nextReminder.scheduledAt),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        '$activeCount reminder(s) | next $date at $time',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class NoteEditorSheet extends ConsumerStatefulWidget {
  const NoteEditorSheet({
    super.key,
    required this.userId,
    this.note,
    this.embedded = false,
    this.onClose,
  });

  final String userId;
  final Note? note;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  ConsumerState<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<NoteEditorSheet> {
  static const _noteColors = <int>[
    0xFFFFF8E1,
    0xFFE1F5FE,
    0xFFE8F5E9,
    0xFFFCE4EC,
    0xFFF3E5F5,
  ];
  final SmartReminderParser _smartReminderParser = SmartReminderParser();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  late final NoteDraftController _draftController;
  late String _lastContentValue;
  bool _isUploadingImage = false;
  bool _isCreatingSmartReminder = false;
  bool _isAutoFormattingContent = false;
  bool _allowRoutePop = false;
  String? _dismissedSuggestionKey;
  Object? _reportedSaveError;

  List<String> get _imageUrls => _draftController.draft.imageUrls;
  int get _selectedColor => _draftController.draft.color;
  String? get _selectedCategory => _draftController.draft.category;
  String? get _workingNoteId => _draftController.draft.noteId;
  DateTime? get _workingCreatedAt => _draftController.draft.createdAt;
  bool get _isSaving => _draftController.status == NoteSaveStatus.saving;
  String get _saveStatusLabel {
    if (_draftController.hasUnsavedChanges &&
        _draftController.status != NoteSaveStatus.saving &&
        _draftController.status != NoteSaveStatus.failed) {
      return 'Not saved';
    }

    return switch (_draftController.status) {
      NoteSaveStatus.idle => 'Not saved',
      NoteSaveStatus.saving => 'Saving...',
      NoteSaveStatus.saved => 'Saved',
      NoteSaveStatus.failed => 'Save failed',
    };
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _contentFocusNode = FocusNode();
    _lastContentValue = _contentController.text;
    final defaultCategory = ref
        .read(currentUserSettingsProvider)
        .asData
        ?.value
        ?.defaultNoteTag;
    _draftController = NoteDraftController(
      initialDraft: NoteDraft(
        noteId: widget.note?.id,
        title: widget.note?.title ?? '',
        body: widget.note?.content ?? '',
        category:
            NoteCategory.fromTags(widget.note?.tags ?? const []) ??
            (widget.note == null ? defaultCategory : null),
        imageUrls: List<String>.from(widget.note?.images ?? const []),
        color: widget.note?.color ?? _noteColors.first,
        createdAt: widget.note?.createdAt,
        updatedAt: widget.note?.updatedAt ?? DateTime.now(),
      ),
      save: _persistDraft,
    )..addListener(_handleDraftStateChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _draftController
      ..removeListener(_handleDraftStateChanged)
      ..dispose();
    super.dispose();
  }

  Future<bool> _saveNow() async {
    if (_isSaving || _isUploadingImage) {
      return false;
    }

    final hasText =
        _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty;
    if (!hasText && _workingNoteId == null) {
      _showMessage('Add a title or note content first.');
      return false;
    }

    _draftController
      ..updateTitle(_titleController.text)
      ..updateBody(_contentController.text);
    final saved = await _draftController.flushPendingSave();
    if (!mounted) {
      return saved;
    }
    if (saved) {
      _showMessage('Saved.');
    } else {
      _showMessage('Save failed. Your draft is still open; please try again.');
    }
    return saved;
  }

  Future<NoteDraftSaveResult> _persistDraft(NoteDraft draft) async {
    final notesService = ref.read(notesServiceProvider);
    final title = _normalizeTitle(draft.title);
    final tags = draft.category == null ? const <String>[] : [draft.category!];
    final now = DateTime.now();

    debugPrint(
      '[NoteEditor] event=autosave_start noteId=${draft.noteId ?? 'new'} '
      'category=${draft.category} images=${draft.imageUrls.length}',
    );
    try {
      if (draft.noteId == null || draft.noteId!.isEmpty) {
        final created = await notesService.createNote(
          userId: widget.userId,
          title: title,
          content: draft.body,
          color: draft.color,
          tags: tags,
          images: draft.imageUrls,
        );
        debugPrint(
          '[NoteEditor] event=autosave_create_success noteId=${created.id}',
        );
        return NoteDraftSaveResult(
          noteId: created.id,
          createdAt: created.createdAt,
          updatedAt: created.updatedAt,
        );
      }

      final updated = Note(
        id: draft.noteId!,
        userId: widget.userId,
        title: title,
        isPinned: widget.note?.isPinned ?? false,
        createdAt: draft.createdAt ?? widget.note?.createdAt ?? now,
        updatedAt: now,
        tags: tags,
        content: draft.body,
        color: draft.color,
        images: draft.imageUrls,
      );
      await notesService.updateNote(updated);
      debugPrint(
        '[NoteEditor] event=autosave_update_success noteId=${updated.id}',
      );
      return NoteDraftSaveResult(
        noteId: updated.id,
        createdAt: updated.createdAt,
        updatedAt: now,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NoteEditor] event=autosave_failure noteId=${draft.noteId ?? 'new'} '
        'error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  void _handleDraftStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});

    final error = _draftController.lastError;
    if (_draftController.status == NoteSaveStatus.failed &&
        error != null &&
        error != _reportedSaveError) {
      _reportedSaveError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('Save failed: $error');
        }
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _closeEditor() async {
    if (_draftController.hasUnsavedChanges || _isSaving) {
      final saved = await _draftController.flushPendingSave();
      if (!saved) {
        if (mounted) {
          _showMessage(
            'Could not close because the latest changes are not saved.',
          );
        }
        return;
      }
    }
    if (mounted) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        _allowRoutePop = true;
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage) {
      return;
    }

    try {
      debugPrint('[NoteEditor] event=image_pick_start');
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) {
        debugPrint('[NoteEditor] event=image_pick_cancelled');
        return;
      }

      setState(() {
        _isUploadingImage = true;
      });
      debugPrint('[NoteEditor] event=image_pick_success name=${image.name}');

      final note = await _ensureWorkingNote();
      final imageUrl = await ref
          .read(notesServiceProvider)
          .uploadNoteImage(
            userId: widget.userId,
            noteId: note.id,
            image: image,
          );

      if (!mounted) {
        return;
      }

      _draftController.updateImages([..._imageUrls, imageUrl]);
      final saved = await _draftController.saveNow();
      if (!saved) {
        throw StateError('The image uploaded but its note update failed.');
      }
      debugPrint(
        '[NoteEditor] event=image_url_update_success noteId=${note.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NoteEditor] event=image_flow_failure error=$error\n$stackTrace',
      );
      if (mounted) {
        _showMessage(
          'Could not add this image. Your note is safe; please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _removeImage(String imageUrl) {
    _draftController.updateImages(
      _imageUrls.where((url) => url != imageUrl).toList(),
    );
  }

  void _insertTask() {
    final content = _contentController.text;
    final nextContent = content.isEmpty
        ? '- '
        : content.endsWith('\n')
        ? '$content- '
        : '$content\n- ';
    _replaceEditorContent(nextContent);
    _contentController.selection = TextSelection.collapsed(
      offset: nextContent.length,
    );
    _contentFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final smartSuggestion = _currentSuggestion();
    final workingNoteId = _workingNoteId;
    final editorSurface = AppColors.surface;
    final editorForeground = AppColors.textFor(editorSurface);
    final editorMutedForeground = AppColors.mutedTextFor(editorSurface);
    final taskReminders = workingNoteId == null
        ? const <Reminder>[]
        : ref.watch(noteRemindersStreamProvider(workingNoteId)).asData?.value ??
              const <Reminder>[];
    final smartRemindersEnabled =
        ref
            .watch(currentUserSettingsProvider)
            .asData
            ?.value
            ?.smartRemindersEnabled ??
        true;

    return PopScope(
      canPop: widget.embedded || _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.embedded) {
          return;
        }
        unawaited(_closeEditor());
      },
      child: SafeArea(
        child: Align(
          alignment: widget.embedded ? Alignment.topCenter : Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: SizedBox(
              height: widget.embedded
                  ? double.infinity
                  : MediaQuery.sizeOf(context).height * 0.92,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.embedded ? AppSpacing.lg : AppSpacing.md,
                  AppSpacing.md,
                  widget.embedded ? AppSpacing.lg : AppSpacing.md,
                  bottomInset + AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _closeEditor,
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppChip(
                          label: _selectedCategory ?? 'No category',
                          color: Color(_selectedColor),
                        ),
                        const Spacer(),
                        if (widget.embedded) ...[
                          Text(
                            _saveStatusLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color:
                                      _draftController.status ==
                                          NoteSaveStatus.failed
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                          ),
                          if (_draftController.status ==
                              NoteSaveStatus.failed) ...[
                            const SizedBox(width: AppSpacing.sm),
                            OutlinedButton(
                              onPressed: _saveNow,
                              child: const Text('Retry save'),
                            ),
                          ],
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        PopupMenuButton<_EditorMenuAction>(
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (action) {
                            switch (action) {
                              case _EditorMenuAction.saveNow:
                                unawaited(_saveNow());
                                return;
                              case _EditorMenuAction.reminders:
                                _openManualReminder();
                                return;
                              case _EditorMenuAction.close:
                                _closeEditor();
                                return;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _EditorMenuAction.saveNow,
                              child: Text('Save now'),
                            ),
                            PopupMenuItem(
                              value: _EditorMenuAction.reminders,
                              child: Text('Manage reminders'),
                            ),
                            PopupMenuItem(
                              value: _EditorMenuAction.close,
                              child: Text('Close editor'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _titleController,
                              onChanged: _draftController.updateTitle,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              style: Theme.of(context).textTheme.headlineMedium,
                              decoration: const InputDecoration(
                                hintText: 'Give this thought a title',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            AppCard(
                              color: editorSurface,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: TextField(
                                controller: _contentController,
                                focusNode: _contentFocusNode,
                                onChanged: _handleContentChanged,
                                minLines: widget.embedded ? 10 : 8,
                                maxLines: null,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: editorForeground),
                                cursorColor: editorForeground,
                                decoration: InputDecoration(
                                  hintText:
                                      'Write freely...\nStart a task with "- "',
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: editorMutedForeground),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                ),
                              ),
                            ),
                            if (smartSuggestion != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _SmartReminderSuggestionBar(
                                  key: ValueKey(
                                    _suggestionKey(smartSuggestion),
                                  ),
                                  parsedReminder: smartSuggestion,
                                  isLoading: _isCreatingSmartReminder,
                                  onCreate: _createSmartReminder,
                                  onDismiss: () {
                                    setState(() {
                                      _dismissedSuggestionKey = _suggestionKey(
                                        smartSuggestion,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            _EditorTaskPreview(
                              tasks: TaskParser.extractTasks(
                                _contentController.text,
                              ),
                              taskSuggestions: smartRemindersEnabled
                                  ? TaskParser.extractTaskReminderSuggestions(
                                      _contentController.text,
                                      _smartReminderParser,
                                    )
                                  : const <TaskReminderSuggestion>[],
                              reminders: taskReminders,
                              onToggleTask: (task) {
                                _replaceEditorContent(
                                  TaskParser.toggleTask(
                                    _contentController.text,
                                    task.lineIndex,
                                  ),
                                );
                              },
                              onCreateReminder:
                                  _createTaskReminderFromSuggestion,
                              onLongPressTask: _showEditorTaskActions,
                            ),
                            if (_imageUrls.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              _EditorImageGallery(
                                noteId: widget.note?.id ?? 'draft',
                                images: _imageUrls,
                                onRemove: _removeImage,
                                maxImageHeight: widget.embedded ? 340 : null,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Category',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: NoteCategory.defaults.map((category) {
                                final isSelected =
                                    _selectedCategory == category;
                                return ChoiceChip(
                                  selected: isSelected,
                                  label: Text(category),
                                  onSelected: (_) {
                                    debugPrint(
                                      '[NoteEditor] event=tag_update category=$category',
                                    );
                                    _draftController.updateCategory(category);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Note color',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: _noteColors.map((color) {
                                final isSelected = _selectedColor == color;
                                final tag = NoteColorTag.fromColor(color);

                                return Tooltip(
                                  message: tag.label,
                                  child: InkWell(
                                    onTap: () =>
                                        _draftController.updateColor(color),
                                    customBorder: const CircleBorder(),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Color(color),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? tag.accent
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (widget.embedded) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _EditorActionToolbar(
                                isUploadingImage: _isUploadingImage,
                                onAddImage: _pickAndUploadImage,
                                onAddReminder: _openManualReminder,
                                onAddTask: _insertTask,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!widget.embedded) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _isUploadingImage
                                  ? null
                                  : _pickAndUploadImage,
                              icon: _isUploadingImage
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                              tooltip: 'Add image',
                            ),
                            IconButton(
                              onPressed: _openManualReminder,
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                              ),
                              tooltip: 'Add reminder',
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Text(
                                _saveStatusLabel,
                                key: ValueKey(_draftController.status),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          _draftController.status ==
                                              NoteSaveStatus.failed
                                          ? Theme.of(context).colorScheme.error
                                          : null,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton.icon(
                              onPressed: (_isSaving || _isUploadingImage)
                                  ? null
                                  : _saveNow,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: const Text('Save now'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _notePreview(Note note) {
    final title = note.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title.length > 80 ? '${title.substring(0, 80)}...' : title;
    }

    final preview = note.content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'Untitled note');

    return preview.length > 80 ? '${preview.substring(0, 80)}...' : preview;
  }

  String? _normalizeTitle(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _handleContentChanged(String value) {
    if (_isAutoFormattingContent) {
      return;
    }

    final isSingleCharacterInsertion =
        value.length == _lastContentValue.length + 1;
    final formattedValue = isSingleCharacterInsertion
        ? _autoFormatTaskPrefix(value)
        : value;
    if (formattedValue != value) {
      final selection = _contentController.selection;
      final baseOffset = selection.baseOffset;
      final extentOffset = selection.extentOffset;
      final updatedBaseOffset = baseOffset >= 0 ? baseOffset + 1 : baseOffset;
      final updatedExtentOffset = extentOffset >= 0
          ? extentOffset + 1
          : extentOffset;

      _isAutoFormattingContent = true;
      _contentController.value = TextEditingValue(
        text: formattedValue,
        selection: TextSelection(
          baseOffset: updatedBaseOffset,
          extentOffset: updatedExtentOffset,
        ),
      );
      _isAutoFormattingContent = false;
      value = formattedValue;
    }
    _lastContentValue = value;
    _draftController.updateBody(value);

    final parsed = _smartReminderParser.parse(
      TaskParser.extractPlainTextLines(value).join('\n'),
    );
    final currentKey = parsed == null ? null : _suggestionKey(parsed);

    setState(() {
      if (_dismissedSuggestionKey != null &&
          currentKey != _dismissedSuggestionKey) {
        _dismissedSuggestionKey = null;
      }
    });
  }

  String _autoFormatTaskPrefix(String value) {
    final selection = _contentController.selection;
    if (!selection.isCollapsed || selection.baseOffset < 0) {
      return value;
    }

    final cursorOffset = selection.baseOffset;
    if (cursorOffset == 0 || cursorOffset > value.length) {
      return value;
    }

    if (value[cursorOffset - 1] != '-') {
      return value;
    }

    final lineStart = value.lastIndexOf('\n', cursorOffset - 1) + 1;
    final beforeDash = value.substring(lineStart, cursorOffset - 1);
    final afterDash = value.substring(cursorOffset);

    if (beforeDash.trim().isNotEmpty || afterDash.startsWith(' ')) {
      return value;
    }

    return '${value.substring(0, cursorOffset)} ${value.substring(cursorOffset)}';
  }

  ParsedReminder? _currentSuggestion() {
    final smartRemindersEnabled =
        ref
            .read(currentUserSettingsProvider)
            .asData
            ?.value
            ?.smartRemindersEnabled ??
        true;
    if (!smartRemindersEnabled) {
      return null;
    }

    final parsed = _smartReminderParser.parse(
      TaskParser.extractPlainTextLines(_contentController.text).join('\n'),
    );
    if (parsed == null) {
      return null;
    }

    final key = _suggestionKey(parsed);
    if (_dismissedSuggestionKey == key) {
      return null;
    }

    return parsed;
  }

  Future<void> _createSmartReminder() async {
    final parsed = _currentSuggestion();
    if (parsed == null || _isCreatingSmartReminder) {
      return;
    }

    setState(() {
      _isCreatingSmartReminder = true;
    });

    try {
      final note = await _ensureWorkingNote();
      await ref
          .read(remindersServiceProvider)
          .createReminder(
            userId: widget.userId,
            noteId: note.id,
            notePreview: _notePreview(
              note.copyWith(
                title: _normalizeTitle(_titleController.text),
                content: _contentController.text.trim(),
                color: _selectedColor,
                images: _imageUrls,
              ),
            ),
            scheduledAt: parsed.dateTime,
            repeat: RepeatType.none,
            notificationId: DateTime.now().microsecondsSinceEpoch.remainder(
              2147483647,
            ),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _dismissedSuggestionKey = _suggestionKey(parsed);
      });

      _showMessage('Reminder created for ${_formatDateTime(parsed.dateTime)}.');
    } catch (error) {
      _showMessage('Could not create reminder: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSmartReminder = false;
        });
      }
    }
  }

  Future<void> _createTaskReminderFromSuggestion(
    NoteTask task,
    ParsedReminder suggestion,
  ) async {
    try {
      final note = await _ensureWorkingNote();
      await ref
          .read(remindersServiceProvider)
          .createReminder(
            userId: widget.userId,
            noteId: note.id,
            taskLineIndex: task.lineIndex,
            notePreview: task.text,
            scheduledAt: suggestion.dateTime,
            repeat: RepeatType.none,
            notificationId: DateTime.now().microsecondsSinceEpoch.remainder(
              2147483647,
            ),
          );
      _showMessage('Reminder added for task.');
    } catch (error) {
      _showMessage('Could not add reminder: $error');
    }
  }

  Future<void> _openManualReminder() async {
    if (_contentController.text.trim().isEmpty) {
      _showMessage('Add some note content first.');
      return;
    }

    try {
      final note = await _ensureWorkingNote();
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return NoteRemindersSheet(
            note: note.copyWith(
              title: _normalizeTitle(_titleController.text),
              content: _contentController.text.trim(),
              color: _selectedColor,
              images: _imageUrls,
            ),
          );
        },
      );
    } catch (error) {
      _showMessage('Could not open reminders: $error');
    }
  }

  Future<void> _showEditorTaskActions(
    NoteTask task,
    Reminder? reminder,
    ParsedReminder? suggestion,
  ) async {
    final action = await TaskActionsBottomSheet.show(
      context,
      hasReminder: reminder != null,
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case TaskAction.reminder:
        await _pickEditorTaskReminder(task, reminder, suggestion);
        return;
      case TaskAction.delete:
        await _confirmDeleteEditorTask(task, reminder);
        return;
    }
  }

  Future<void> _pickEditorTaskReminder(
    NoteTask task,
    Reminder? reminder,
    ParsedReminder? suggestion,
  ) async {
    final initial =
        reminder?.scheduledAt ??
        suggestion?.dateTime ??
        DateTime.now().add(const Duration(minutes: 5));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      _showMessage('Choose a future time.');
      return;
    }

    try {
      final note = await _ensureWorkingNote();
      if (reminder == null) {
        await ref
            .read(remindersServiceProvider)
            .createReminder(
              userId: widget.userId,
              noteId: note.id,
              taskLineIndex: task.lineIndex,
              notePreview: task.text,
              scheduledAt: scheduledAt,
              repeat: RepeatType.none,
              notificationId: DateTime.now().microsecondsSinceEpoch.remainder(
                2147483647,
              ),
            );
        _showMessage('Reminder added for task.');
        return;
      }

      await ref
          .read(remindersServiceProvider)
          .updateReminder(
            reminder.copyWith(
              scheduledAt: scheduledAt,
              notePreview: task.text,
              taskLineIndex: task.lineIndex,
            ),
          );
      _showMessage('Reminder updated.');
    } catch (error) {
      _showMessage('Could not save reminder: $error');
    }
  }

  Future<void> _confirmDeleteEditorTask(
    NoteTask task,
    Reminder? reminder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this task?'),
          content: Text('Delete "${task.text}" from this note?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    if (reminder != null) {
      await ref.read(remindersServiceProvider).deleteReminder(reminder);
    }
    _replaceEditorContent(
      TaskParser.deleteTask(_contentController.text, task.lineIndex),
    );
  }

  void _replaceEditorContent(String content) {
    final oldOffset = _contentController.selection.baseOffset;
    final nextOffset = oldOffset < 0
        ? content.length
        : math.min(math.max(oldOffset, 0), content.length);
    setState(() {
      _lastContentValue = content;
      _contentController.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: nextOffset),
      );
    });
    _draftController.updateBody(content);
  }

  String _suggestionKey(ParsedReminder parsed) {
    return '${parsed.matchedPhrase}-${parsed.dateTime.toIso8601String()}';
  }

  String _formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatShortDate(value);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date at $time';
  }

  Note _currentNoteSnapshot() {
    return Note(
      id: _workingNoteId ?? widget.note?.id ?? '',
      userId: widget.userId,
      title: _normalizeTitle(_titleController.text),
      isPinned: widget.note?.isPinned ?? false,
      createdAt: _workingCreatedAt ?? widget.note?.createdAt ?? DateTime.now(),
      updatedAt: widget.note?.updatedAt ?? DateTime.now(),
      tags: _selectedCategory == null
          ? const <String>[]
          : <String>[_selectedCategory!],
      content: _contentController.text.trim(),
      color: _selectedColor,
      images: _imageUrls,
    );
  }

  Future<Note> _ensureWorkingNote() async {
    final existingId = _workingNoteId;
    if (existingId != null && existingId.isNotEmpty) {
      final saved = await _draftController.saveNow();
      if (!saved) {
        throw StateError('Save the latest note changes before continuing.');
      }
      return _currentNoteSnapshot().copyWith(id: existingId);
    }

    final saved = await _draftController.saveNow(force: true);
    final noteId = _workingNoteId;
    if (!saved || noteId == null || noteId.isEmpty) {
      throw StateError('Could not create the note before continuing.');
    }
    return _currentNoteSnapshot().copyWith(id: noteId);
  }
}

class _EditorTaskPreview extends StatelessWidget {
  const _EditorTaskPreview({
    required this.tasks,
    required this.taskSuggestions,
    required this.reminders,
    required this.onToggleTask,
    required this.onCreateReminder,
    required this.onLongPressTask,
  });

  final List<NoteTask> tasks;
  final List<TaskReminderSuggestion> taskSuggestions;
  final List<Reminder> reminders;
  final ValueChanged<NoteTask> onToggleTask;
  final Future<void> Function(NoteTask task, ParsedReminder suggestion)
  onCreateReminder;
  final void Function(
    NoteTask task,
    Reminder? reminder,
    ParsedReminder? suggestion,
  )
  onLongPressTask;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Text(
        'Tasks appear automatically when a line starts with - .',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final activeTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList();
    final suggestionsByLine = {
      for (final suggestion in taskSuggestions)
        suggestion.task.lineIndex: suggestion.reminder,
    };
    final remindersByLine = <int, Reminder>{
      for (final reminder in reminders)
        if (reminder.taskLineIndex != null) reminder.taskLineIndex!: reminder,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Detected tasks',
          subtitle:
              '${tasks.length} task${tasks.length == 1 ? '' : 's'} from note text',
        ),
        if (activeTasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Active', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (activeTasks.isNotEmpty)
          ...activeTasks.map((task) {
            final reminder = remindersByLine[task.lineIndex];
            final suggestion = reminder == null
                ? suggestionsByLine[task.lineIndex]
                : null;
            return _TaskRow(
              task: task,
              onToggle: () => onToggleTask(task),
              reminder: reminder,
              suggestion: suggestion,
              onSuggestionTap: suggestion == null
                  ? null
                  : () => onCreateReminder(task, suggestion),
              onLongPress: () => onLongPressTask(task, reminder, suggestion),
            );
          }),
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Completed', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          ...completedTasks.map((task) {
            final reminder = remindersByLine[task.lineIndex];
            return _TaskRow(
              task: task,
              onToggle: () => onToggleTask(task),
              reminder: reminder,
              onLongPress: () => onLongPressTask(task, reminder, null),
            );
          }),
        ],
      ],
    );
  }
}

class _TaskListView extends ConsumerStatefulWidget {
  const _TaskListView({
    super.key,
    required this.note,
    required this.tasks,
    required this.taskSuggestions,
    required this.reminders,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  final Note note;
  final List<NoteTask> tasks;
  final List<TaskReminderSuggestion> taskSuggestions;
  final List<Reminder> reminders;
  final Future<void> Function(NoteTask task, bool isCompleted) onToggleTask;
  final Future<void> Function(NoteTask task) onDeleteTask;

  @override
  ConsumerState<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<_TaskListView> {
  static const Duration _reorderDelay = Duration(milliseconds: 380);
  final Map<int, _PendingTaskState> _pendingStates = {};

  @override
  void dispose() {
    for (final pending in _pendingStates.values) {
      pending.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTasks = widget.tasks
        .map(
          (task) => _RenderableTask(
            task: task,
            displayCompleted:
                _pendingStates[task.lineIndex]?.targetCompleted ??
                task.isCompleted,
            sectionCompleted: _sectionCompleted(task),
          ),
        )
        .toList();
    final activeTasks = effectiveTasks
      ..sort((a, b) {
        if (a.sectionCompleted == b.sectionCompleted) {
          return a.task.lineIndex.compareTo(b.task.lineIndex);
        }
        return a.sectionCompleted ? 1 : -1;
      });
    final active = activeTasks.where((item) => !item.sectionCompleted).toList();
    final completed = activeTasks
        .where((item) => item.sectionCompleted)
        .toList();
    final remindersByLine = _taskRemindersByLine();
    final suggestionsByLine = {
      for (final suggestion in widget.taskSuggestions)
        suggestion.task.lineIndex: suggestion.reminder,
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...active.map((item) {
            final reminder = remindersByLine[item.task.lineIndex];
            final suggestion = reminder == null
                ? suggestionsByLine[item.task.lineIndex]
                : null;
            return _TaskRow(
              task: item.task.copyWith(isCompleted: item.displayCompleted),
              onToggle: () => _handleToggle(item.task, item.displayCompleted),
              reminder: reminder,
              suggestion: suggestion,
              onSuggestionTap: suggestion == null
                  ? null
                  : () => _createTaskReminder(item.task, suggestion),
              onLongPress: () =>
                  _showTaskActions(item.task, reminder, suggestion),
            );
          }),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Completed', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ...completed.map((item) {
              final reminder = remindersByLine[item.task.lineIndex];
              return _TaskRow(
                task: item.task.copyWith(isCompleted: item.displayCompleted),
                onToggle: () => _handleToggle(item.task, item.displayCompleted),
                reminder: reminder,
                onLongPress: () => _showTaskActions(item.task, reminder, null),
              );
            }),
          ],
        ],
      ),
    );
  }

  bool _sectionCompleted(NoteTask task) {
    final pending = _pendingStates[task.lineIndex];
    if (pending == null || !pending.moveToTargetSection) {
      return task.isCompleted;
    }
    return pending.targetCompleted;
  }

  Map<int, Reminder> _taskRemindersByLine() {
    final map = <int, Reminder>{};
    for (final reminder in widget.reminders) {
      final lineIndex = reminder.taskLineIndex;
      if (lineIndex == null) {
        continue;
      }

      final existing = map[lineIndex];
      if (existing == null ||
          (existing.isCompleted && !reminder.isCompleted) ||
          reminder.scheduledAt.isBefore(existing.scheduledAt)) {
        map[lineIndex] = reminder;
      }
    }

    return map;
  }

  Future<void> _handleToggle(
    NoteTask task,
    bool currentDisplayCompleted,
  ) async {
    final targetCompleted = !currentDisplayCompleted;
    _pendingStates[task.lineIndex]?.timer?.cancel();

    setState(() {
      _pendingStates[task.lineIndex] = _PendingTaskState(
        targetCompleted: targetCompleted,
      );
    });

    final timer = Timer(_reorderDelay, () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingStates[task.lineIndex] = _PendingTaskState(
          targetCompleted: targetCompleted,
          moveToTargetSection: true,
        );
      });

      try {
        await widget.onToggleTask(task, targetCompleted);
      } finally {
        if (mounted) {
          setState(() {
            _pendingStates.remove(task.lineIndex);
          });
        }
      }
    });

    _pendingStates[task.lineIndex] = _PendingTaskState(
      targetCompleted: targetCompleted,
      timer: timer,
    );
  }

  Future<void> _createTaskReminder(
    NoteTask task,
    ParsedReminder suggestion,
  ) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }

    try {
      await ref
          .read(remindersServiceProvider)
          .createReminder(
            userId: user.uid,
            noteId: widget.note.id,
            taskLineIndex: task.lineIndex,
            notePreview: task.text,
            scheduledAt: suggestion.dateTime,
            repeat: RepeatType.none,
            notificationId: DateTime.now().microsecondsSinceEpoch.remainder(
              2147483647,
            ),
          );
      _showMessage('Reminder added for task.');
    } catch (error) {
      _showMessage('Could not add reminder: $error');
    }
  }

  Future<void> _showTaskActions(
    NoteTask task,
    Reminder? reminder,
    ParsedReminder? suggestion,
  ) async {
    final action = await TaskActionsBottomSheet.show(
      context,
      hasReminder: reminder != null,
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case TaskAction.reminder:
        await _pickTaskReminder(task, reminder, suggestion);
        return;
      case TaskAction.delete:
        await _confirmDeleteTask(task, reminder);
        return;
    }
  }

  Future<void> _pickTaskReminder(
    NoteTask task,
    Reminder? reminder,
    ParsedReminder? suggestion,
  ) async {
    final initial =
        reminder?.scheduledAt ??
        suggestion?.dateTime ??
        DateTime.now().add(const Duration(minutes: 5));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      _showMessage('Choose a future time.');
      return;
    }

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }

    try {
      if (reminder == null) {
        await ref
            .read(remindersServiceProvider)
            .createReminder(
              userId: user.uid,
              noteId: widget.note.id,
              taskLineIndex: task.lineIndex,
              notePreview: task.text,
              scheduledAt: scheduledAt,
              repeat: RepeatType.none,
              notificationId: DateTime.now().microsecondsSinceEpoch.remainder(
                2147483647,
              ),
            );
        _showMessage('Reminder added for task.');
        return;
      }

      await ref
          .read(remindersServiceProvider)
          .updateReminder(
            reminder.copyWith(
              scheduledAt: scheduledAt,
              notePreview: task.text,
              taskLineIndex: task.lineIndex,
            ),
          );
      _showMessage('Reminder updated.');
    } catch (error) {
      _showMessage('Could not save reminder: $error');
    }
  }

  Future<void> _confirmDeleteTask(NoteTask task, Reminder? reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this task?'),
          content: Text('Delete "${task.text}" from this note?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final pending = _pendingStates.remove(task.lineIndex);
    pending?.timer?.cancel();
    if (reminder != null) {
      await ref.read(remindersServiceProvider).deleteReminder(reminder);
    }
    await widget.onDeleteTask(task);
    _showMessage('Task deleted.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    this.reminder,
    this.suggestion,
    this.onSuggestionTap,
    this.onLongPress,
  });

  final NoteTask task;
  final VoidCallback onToggle;
  final Reminder? reminder;
  final ParsedReminder? suggestion;
  final VoidCallback? onSuggestionTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final reminderState = reminder == null
        ? null
        : reminder!.isCompleted
        ? ReminderVisualState.completed
        : reminder!.scheduledAt.isBefore(DateTime.now())
        ? ReminderVisualState.missed
        : ReminderVisualState.scheduled;
    final reminderLabel = reminder == null
        ? null
        : reminderState == ReminderVisualState.completed
        ? 'Reminder complete'
        : reminderState == ReminderVisualState.missed
        ? 'Reminder missed'
        : 'Reminder scheduled';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TaskRow(
        text: task.text,
        completed: task.isCompleted,
        onToggle: onToggle,
        onLongPress: onLongPress,
        reminderState: reminderState,
        reminderLabel: reminderLabel,
        suggestionLabel: suggestion == null ? null : 'Remind you?',
        onSuggestionTap: onSuggestionTap,
      ),
    );
  }
}

class _PendingTaskState {
  const _PendingTaskState({
    required this.targetCompleted,
    this.moveToTargetSection = false,
    this.timer,
  });

  final bool targetCompleted;
  final bool moveToTargetSection;
  final Timer? timer;
}

class _RenderableTask {
  const _RenderableTask({
    required this.task,
    required this.displayCompleted,
    required this.sectionCompleted,
  });

  final NoteTask task;
  final bool displayCompleted;
  final bool sectionCompleted;
}

class _SmartReminderSuggestionBar extends StatelessWidget {
  const _SmartReminderSuggestionBar({
    super.key,
    required this.parsedReminder,
    required this.isLoading,
    required this.onCreate,
    required this.onDismiss,
  });

  final ParsedReminder parsedReminder;
  final bool isLoading;
  final Future<void> Function() onCreate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.butter;
    final foreground = AppColors.textFor(background);
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(parsedReminder.dateTime);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(parsedReminder.dateTime));

    return AppCard(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: AppColors.ink.withValues(alpha: 0.08),
      onTap: isLoading ? null : onCreate,
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: AppColors.ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create reminder for $date at $time?',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}

class _NoteColorBadge extends StatelessWidget {
  const _NoteColorBadge({required this.tag});

  final NoteColorTag tag;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tag.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          tag.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tag.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NotesFilterBar extends ConsumerWidget {
  const _NotesFilterBar({required this.tags, required this.filter});

  final List<String> tags;
  final NotesFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...tags.map((tag) {
                  final isSelected = filter.selectedTags.contains(tag);

                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text('#$tag'),
                      onSelected: (_) {
                        ref.read(notesFilterProvider.notifier).toggleTag(tag);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: NoteColorTag.tags.map((tag) {
                    final colorKey = tag.color.toRadixString(16).toUpperCase();
                    final isSelected = filter.selectedColor == colorKey;

                    return _ColorFilterButton(
                      tag: tag,
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(notesFilterProvider.notifier)
                            .toggleColor(colorKey);
                      },
                    );
                  }).toList(),
                ),
              ),
              if (filter.hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () {
                    ref.read(notesFilterProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ColorFilterButton extends StatelessWidget {
  const _ColorFilterButton({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  final NoteColorTag tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tag.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? tag.accent
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? tag.accent.withValues(alpha: 0.08) : null,
          ),
          child: CircleAvatar(radius: 12, backgroundColor: Color(tag.color)),
        ),
      ),
    );
  }
}

class _NoteTagChip extends StatelessWidget {
  const _NoteTagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NoteImageGallery extends StatelessWidget {
  const _NoteImageGallery({required this.noteId, required this.images});

  final String noteId;
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...images.asMap().entries.map((entry) {
          final index = entry.key;
          final imageUrl = entry.value;
          final heroTag = 'note-image-$noteId-$index';

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == images.length - 1 ? 0 : AppSpacing.sm,
            ),
            child: _NoteImageTile(
              imageUrl: imageUrl,
              heroTag: heroTag,
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    opaque: false,
                    barrierColor: Colors.transparent,
                    transitionDuration: const Duration(milliseconds: 260),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 220,
                    ),
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return _FullscreenImageViewer(
                        imageUrl: imageUrl,
                        heroTag: heroTag,
                        animation: animation,
                      );
                    },
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _EditorActionToolbar extends StatelessWidget {
  const _EditorActionToolbar({
    required this.isUploadingImage,
    required this.onAddImage,
    required this.onAddReminder,
    required this.onAddTask,
  });

  final bool isUploadingImage;
  final VoidCallback onAddImage;
  final VoidCallback onAddReminder;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          TextButton.icon(
            onPressed: isUploadingImage ? null : onAddImage,
            icon: isUploadingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add image'),
          ),
          TextButton.icon(
            onPressed: onAddReminder,
            icon: const Icon(Icons.notifications_none_rounded),
            label: const Text('Add reminder'),
          ),
          TextButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.check_box_outlined),
            label: const Text('Add task'),
          ),
        ],
      ),
    );
  }
}

class _EditorImageGallery extends StatelessWidget {
  const _EditorImageGallery({
    required this.noteId,
    required this.images,
    required this.onRemove,
    this.maxImageHeight,
  });

  final String noteId;
  final List<String> images;
  final ValueChanged<String> onRemove;
  final double? maxImageHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...images.asMap().entries.map((entry) {
          final index = entry.key;
          final imageUrl = entry.value;
          final heroTag = 'editor-image-$noteId-$index';

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == images.length - 1 ? 0 : AppSpacing.sm,
            ),
            child: Stack(
              children: [
                _NoteImageTile(
                  imageUrl: imageUrl,
                  heroTag: heroTag,
                  maxHeight: maxImageHeight,
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        opaque: false,
                        barrierColor: Colors.transparent,
                        transitionDuration: const Duration(milliseconds: 260),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 220,
                        ),
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return _FullscreenImageViewer(
                            imageUrl: imageUrl,
                            heroTag: heroTag,
                            animation: animation,
                          );
                        },
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onRemove(imageUrl),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _NoteImageTile extends StatelessWidget {
  const _NoteImageTile({
    required this.imageUrl,
    required this.heroTag,
    required this.onTap,
    this.maxHeight,
  });

  final String imageUrl;
  final String heroTag;
  final VoidCallback onTap;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: maxHeight,
              fit: maxHeight == null ? BoxFit.fitWidth : BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (context, error, stackTrace) {
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.animation,
  });

  final String imageUrl;
  final String heroTag;
  final Animation<double> animation;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final dragProgress = (_dragOffset.abs() / 220).clamp(0.0, 1.0);
    final backgroundOpacity = (1 - dragProgress * 0.45) * 0.92;
    final scale = 1 - dragProgress * 0.06;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dy;
        });
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragOffset.abs() > 140 || velocity.abs() > 900) {
          Navigator.of(context).pop();
          return;
        }

        setState(() {
          _dragOffset = 0;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FadeTransition(
          opacity: fade,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: backgroundOpacity),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: Transform.scale(
                      scale: scale,
                      child: Hero(
                        tag: widget.heroTag,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            widget.imageUrl,
                            fit: BoxFit.contain,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
