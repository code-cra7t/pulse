import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../reminders/data/smart_reminder_parser.dart';
import '../../reminders/models/parsed_reminder.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/models/repeat_type.dart';
import '../../reminders/presentation/note_reminders_sheet.dart';
import '../../reminders/providers/reminders_providers.dart';
import '../../../core/services/connectivity_providers.dart';
import '../models/note_color_tag.dart';
import '../models/note.dart';
import '../models/note_task.dart';
import '../providers/notes_providers.dart';
import '../utils/task_parser.dart';
import '../utils/timestamp_formatter.dart';

class NotesHomeScreen extends ConsumerStatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  ConsumerState<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends ConsumerState<NotesHomeScreen> {
  StreamSubscription<String?>? _notificationSelectionSubscription;
  String? _highlightedNoteId;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final notifications = ref.read(localNotificationsServiceProvider);
    _highlightedNoteId = notifications.selectedNoteId;
    _notificationSelectionSubscription = notifications.selectedNoteStream.listen((
      noteId,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _highlightedNoteId = noteId;
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
    final notes = ref.watch(filteredNotesProvider);
    final allTags = ref.watch(allNoteTagsProvider);
    final filter = ref.watch(notesFilterProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final hasError = notesAsync.hasError;
    final isOnline = ref.watch(isOnlineProvider).asData?.value ?? true;

    if (_searchController.text != filter.searchQuery) {
      _searchController.value = _searchController.value.copyWith(
        text: filter.searchQuery,
        selection: TextSelection.collapsed(offset: filter.searchQuery.length),
        composing: TextRange.empty,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PulseNotes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(notesFilterProvider.notifier).setSearchQuery(value);
              },
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search notes',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text(
                      'Are you sure you want to log out?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true) {
                await ref.read(authServiceProvider).signOut();
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: user == null
            ? null
            : () {
                _openEditor(context, user: user);
              },
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: hasError
          ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load notes.\n${notesAsync.error}',
              textAlign: TextAlign.center,
            ),
          ),
        )
          : SafeArea(
              top: false,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                cacheExtent: 600,
                slivers: [
                  if (allTags.isNotEmpty || allNotes.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _NotesFilterBar(
                        tags: allTags,
                        filter: filter,
                      ),
                    ),
                  if (notes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyNotesState(
                        title: allNotes.isEmpty && !filter.hasActiveFilters
                            ? 'No notes yet'
                            : filter.searchQuery.trim().isNotEmpty
                                ? 'No search results'
                                : 'No matching notes',
                        message: allNotes.isEmpty && !filter.hasActiveFilters
                            ? 'Create your first note and it will appear here in real time.'
                            : filter.searchQuery.trim().isNotEmpty
                                ? 'Try a different keyword or clear your filters.'
                                : 'Try adjusting your filters or create a note that matches them.',
                        trailingMessage: allNotes.isEmpty && !isOnline
                            ? 'You are offline. Cached notes and new changes will sync when connection returns.'
                            : null,
                        actionLabel: allNotes.isEmpty && !filter.hasActiveFilters
                            ? 'Create note'
                            : 'Clear filters',
                        onCreate: allNotes.isEmpty && !filter.hasActiveFilters
                            ? (user == null
                                ? null
                                : () {
                                    _openEditor(context, user: user);
                                  })
                            : () {
                                ref.read(notesFilterProvider.notifier).clear();
                              },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final noteIndex = index ~/ 2;
                          if (index.isOdd) {
                            return const SizedBox(height: AppSpacing.sm);
                          }

                          final note = notes[noteIndex];
                          return _NoteCard(
                            note: note,
                            isHighlighted: _highlightedNoteId == note.id,
                            onEdit: user == null
                                ? null
                                : () {
                                    _openEditor(context, user: user, note: note);
                                  },
                            onTogglePin: () => _togglePin(note),
                            onManageReminders: () => _openReminders(context, note),
                            onToggleTask: (task, isCompleted) =>
                                _setTaskCompletion(note, task, isCompleted),
                            onDeleteTask: (task) => _deleteTask(note, task),
                            onDelete: () => _deleteNote(context, note.id),
                          );
                        }, childCount: math.max(0, notes.length * 2 - 1)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _deleteNote(BuildContext context, String noteId) async {
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
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        await ref.read(remindersServiceProvider).deleteRemindersForNote(
              userId: user.uid,
              noteId: noteId,
            );
      }

      await ref.read(notesServiceProvider).deleteNote(noteId);
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

  Future<void> _setTaskCompletion(
    Note note,
    NoteTask task,
    bool isCompleted,
  ) async {
    final updatedContent = TaskParser.setTaskCompletion(
      note.content,
      task.lineIndex,
      isCompleted,
    );
    await ref.read(notesServiceProvider).updateNote(
          note.copyWith(content: updatedContent),
        );
  }

  Future<void> _deleteTask(Note note, NoteTask task) async {
    final updatedContent = TaskParser.deleteTask(note.content, task.lineIndex);
    await ref.read(notesServiceProvider).updateNote(
          note.copyWith(content: updatedContent),
        );
  }

  Future<void> _togglePin(Note note) async {
    await ref.read(notesServiceProvider).updateNote(
          note.copyWith(isPinned: !note.isPinned),
        );
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState({
    this.title = 'No notes yet',
    this.message = 'Create your first note and it will appear here in real time.',
    this.actionLabel = 'Create note',
    this.trailingMessage,
    this.onCreate,
  });

  final String title;
  final String message;
  final String actionLabel;
  final String? trailingMessage;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (trailingMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                trailingMessage!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onCreate, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

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
    final reminders = ref.watch(noteRemindersStreamProvider(note.id)).asData?.value ??
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
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
                _NoteImageGallery(
                  noteId: note.id,
                  images: note.images,
                ),
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
    ));
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
  const NoteEditorSheet({super.key, required this.userId, this.note});

  final String userId;
  final Note? note;

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
  late List<String> _imageUrls;
  late int _selectedColor;
  String? _workingNoteId;
  DateTime? _workingCreatedAt;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isCreatingSmartReminder = false;
  bool _isAutoFormattingContent = false;
  String? _dismissedSuggestionKey;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.note?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _imageUrls = List<String>.from(widget.note?.images ?? const []);
    _selectedColor = widget.note?.color ?? _noteColors.first;
    _workingNoteId = widget.note?.id;
    _workingCreatedAt = widget.note?.createdAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || _isUploadingImage) {
      return;
    }

    final content = _contentController.text.trim();
    final title = _normalizeTitle(_titleController.text);
    if (content.isEmpty) {
      _showMessage('Add some note content first.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final notesService = ref.read(notesServiceProvider);

      if (_workingNoteId == null) {
        final createdNote = await notesService.createNote(
          userId: widget.userId,
          title: title,
          content: content,
          color: _selectedColor,
          images: _imageUrls,
        );
        _workingNoteId = createdNote.id;
        _workingCreatedAt = createdNote.createdAt;
      } else {
        final updatedNote = _currentNoteSnapshot().copyWith(
          title: title,
          content: content,
          color: _selectedColor,
          images: _imageUrls,
        );

        await notesService.updateNote(updatedNote);
        await ref.read(remindersServiceProvider).refreshReminderPreviewsForNote(
              userId: widget.userId,
              noteId: updatedNote.id,
              notePreview: _notePreview(updatedNote),
            );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showMessage('Save failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage) {
      return;
    }

    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageUrl = await ref.read(notesServiceProvider).uploadNoteImage(
            userId: widget.userId,
            image: image,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _imageUrls = [..._imageUrls, imageUrl];
      });
    } catch (error) {
      _showMessage('Image upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _removeImage(String imageUrl) {
    setState(() {
      _imageUrls = _imageUrls.where((url) => url != imageUrl).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final smartSuggestion = _currentSuggestion();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            bottomInset + AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.note == null ? 'Create note' : 'Edit note',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: 'Title',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _contentController,
                        onChanged: _handleContentChanged,
                        minLines: 8,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (smartSuggestion != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _SmartReminderSuggestionBar(
                            key: ValueKey(_suggestionKey(smartSuggestion)),
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
                        tasks: TaskParser.extractTasks(_contentController.text),
                        taskSuggestions: TaskParser.extractTaskReminderSuggestions(
                          _contentController.text,
                          _smartReminderParser,
                        ),
                        onToggleTask: (task) {
                          setState(() {
                            _contentController.text = TaskParser.toggleTask(
                              _contentController.text,
                              task.lineIndex,
                            );
                            _contentController.selection =
                                TextSelection.collapsed(
                              offset: _contentController.text.length,
                            );
                          });
                        },
                      ),
                      if (_imageUrls.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _EditorImageGallery(
                          noteId: widget.note?.id ?? 'draft',
                          images: _imageUrls,
                          onRemove: _removeImage,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _noteColors.map((color) {
                          final isSelected = _selectedColor == color;
                          final tag = NoteColorTag.fromColor(color);

                          return ChoiceChip(
                            selected: isSelected,
                            label: Text(tag.label),
                            avatar: CircleAvatar(
                              radius: 8,
                              backgroundColor: Color(tag.color),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                            selectedColor: tag.accent.withValues(alpha: 0.16),
                            side: BorderSide(
                              color: isSelected
                                  ? tag.accent
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                            labelStyle: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isSelected
                                      ? tag.accent
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _isUploadingImage
                            ? 'Uploading...'
                            : _imageUrls.isEmpty
                                ? 'Attach image'
                                : '${_imageUrls.length} image(s)',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_isSaving || _isUploadingImage) ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.note == null ? 'Create' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ],
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

    final formattedValue = _autoFormatTaskPrefix(value);
    if (formattedValue != value) {
      final selection = _contentController.selection;
      final baseOffset = selection.baseOffset;
      final extentOffset = selection.extentOffset;
      final updatedBaseOffset = baseOffset >= 0 ? baseOffset + 1 : baseOffset;
      final updatedExtentOffset =
          extentOffset >= 0 ? extentOffset + 1 : extentOffset;

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

    final parsed = _smartReminderParser.parse(value);
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
    final parsed = _smartReminderParser.parse(_contentController.text);
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
      await ref.read(remindersServiceProvider).createReminder(
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
            notificationId: DateTime.now()
                .microsecondsSinceEpoch
                .remainder(2147483647),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _dismissedSuggestionKey = _suggestionKey(parsed);
      });

      _showMessage(
        'Reminder created for ${_formatDateTime(parsed.dateTime)}.',
      );
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

  String _suggestionKey(ParsedReminder parsed) {
    return '${parsed.matchedPhrase}-${parsed.dateTime.toIso8601String()}';
  }

  String _formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatShortDate(value);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
    );
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
      tags: widget.note?.tags ?? const <String>[],
      content: _contentController.text.trim(),
      color: _selectedColor,
      images: _imageUrls,
    );
  }

  Future<Note> _ensureWorkingNote() async {
    final existingId = _workingNoteId;
    if (existingId != null && existingId.isNotEmpty) {
      return _currentNoteSnapshot().copyWith(id: existingId);
    }

    final createdNote = await ref.read(notesServiceProvider).createNote(
          userId: widget.userId,
          title: _normalizeTitle(_titleController.text),
          content: _contentController.text.trim(),
          color: _selectedColor,
          images: _imageUrls,
        );

    if (mounted) {
      setState(() {
        _workingNoteId = createdNote.id;
        _workingCreatedAt = createdNote.createdAt;
      });
    } else {
      _workingNoteId = createdNote.id;
      _workingCreatedAt = createdNote.createdAt;
    }

    return createdNote;
  }
}

class _EditorTaskPreview extends StatelessWidget {
  const _EditorTaskPreview({
    required this.tasks,
    required this.taskSuggestions,
    required this.onToggleTask,
  });

  final List<NoteTask> tasks;
  final List<TaskReminderSuggestion> taskSuggestions;
  final ValueChanged<NoteTask> onToggleTask;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detected tasks',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (activeTasks.isNotEmpty) ...activeTasks.map((task) {
          return _TaskRow(
            task: task,
            onToggle: () => onToggleTask(task),
            suggestion: suggestionsByLine[task.lineIndex],
          );
        }),
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Completed',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...completedTasks.map((task) {
            return _TaskRow(
              task: task,
              onToggle: () => onToggleTask(task),
              suggestion: suggestionsByLine[task.lineIndex],
            );
          }),
        ],
      ],
    );
  }
}

class _TaskListView extends ConsumerStatefulWidget {
  const _TaskListView({
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
                _pendingStates[task.lineIndex]?.targetCompleted ?? task.isCompleted,
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
    final completed = activeTasks.where((item) => item.sectionCompleted).toList();
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
            final suggestion =
                reminder == null ? suggestionsByLine[item.task.lineIndex] : null;
            return _TaskRow(
              task: item.task.copyWith(isCompleted: item.displayCompleted),
              onToggle: () => _handleToggle(item.task, item.displayCompleted),
              reminder: reminder,
              suggestion: suggestion,
              onSuggestionTap: suggestion == null
                  ? null
                  : () => _createTaskReminder(item.task, suggestion),
              onLongPress: () => _confirmDeleteTask(item.task),
            );
          }),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Completed',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...completed.map((item) {
              final reminder = remindersByLine[item.task.lineIndex];
              return _TaskRow(
                task: item.task.copyWith(isCompleted: item.displayCompleted),
                onToggle: () => _handleToggle(item.task, item.displayCompleted),
                reminder: reminder,
                onLongPress: () => _confirmDeleteTask(item.task),
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

  Future<void> _handleToggle(NoteTask task, bool currentDisplayCompleted) async {
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
      await ref.read(remindersServiceProvider).createReminder(
            userId: user.uid,
            noteId: widget.note.id,
            taskLineIndex: task.lineIndex,
            notePreview: task.text,
            scheduledAt: suggestion.dateTime,
            repeat: RepeatType.none,
            notificationId: DateTime.now()
                .microsecondsSinceEpoch
                .remainder(2147483647),
          );
      _showMessage('Reminder added for task.');
    } catch (error) {
      _showMessage('Could not add reminder: $error');
    }
  }

  Future<void> _confirmDeleteTask(NoteTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this task?'),
          content: const Text('Delete this task?'),
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
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final completedColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: task.isCompleted ? 0.68 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: task.isCompleted
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.text.isEmpty ? 'Untitled task' : task.text,
                                style: baseStyle?.copyWith(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: task.isCompleted
                                      ? completedColor
                                      : baseStyle.color,
                                ),
                              ),
                            ),
                            if (reminder != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        if (suggestion != null && onSuggestionTap != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: onSuggestionTap,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Remind you?'),
                            ),
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
    final date = MaterialLocalizations.of(context).formatShortDate(
      parsedReminder.dateTime,
    );
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(parsedReminder.dateTime),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create reminder for $date at $time?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            TextButton(
              onPressed: onCreate,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Create'),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              splashRadius: 18,
              tooltip: 'Dismiss',
            ),
          ],
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
  const _NotesFilterBar({
    required this.tags,
    required this.filter,
  });

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
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Color(tag.color),
          ),
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
  const _NoteImageGallery({
    required this.noteId,
    required this.images,
  });

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
                    reverseTransitionDuration: const Duration(milliseconds: 220),
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

class _EditorImageGallery extends StatelessWidget {
  const _EditorImageGallery({
    required this.noteId,
    required this.images,
    required this.onRemove,
  });

  final String noteId;
  final List<String> images;
  final ValueChanged<String> onRemove;

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
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        opaque: false,
                        barrierColor: Colors.transparent,
                        transitionDuration: const Duration(milliseconds: 260),
                        reverseTransitionDuration:
                            const Duration(milliseconds: 220),
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
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
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
  });

  final String imageUrl;
  final String heroTag;
  final VoidCallback onTap;

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
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) {
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
