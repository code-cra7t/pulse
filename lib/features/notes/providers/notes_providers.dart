import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_note_store.dart';
import '../../../core/services/connectivity_providers.dart';
import '../../../core/services/firebase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/notes_service.dart';
import '../models/note.dart';

class NotesFilterState {
  const NotesFilterState({
    this.selectedTags = const <String>{},
    this.selectedColor,
    this.searchQuery = '',
  });

  final Set<String> selectedTags;
  final String? selectedColor;
  final String searchQuery;

  bool get hasActiveFilters {
    return selectedTags.isNotEmpty ||
        selectedColor != null ||
        searchQuery.trim().isNotEmpty;
  }

  NotesFilterState copyWith({
    Set<String>? selectedTags,
    Object? selectedColor = _unsetColorFilter,
    String? searchQuery,
  }) {
    return NotesFilterState(
      selectedTags: selectedTags ?? this.selectedTags,
      selectedColor: identical(selectedColor, _unsetColorFilter)
          ? this.selectedColor
          : selectedColor as String?,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

const _unsetColorFilter = Object();

class NotesFilterNotifier extends Notifier<NotesFilterState> {
  @override
  NotesFilterState build() {
    return const NotesFilterState();
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void toggleTag(String tag) {
    final nextTags = <String>{...state.selectedTags};
    if (nextTags.contains(tag)) {
      nextTags.remove(tag);
    } else {
      nextTags.add(tag);
    }

    state = state.copyWith(selectedTags: nextTags);
  }

  void toggleColor(String color) {
    state = state.copyWith(
      selectedColor: state.selectedColor == color ? null : color,
    );
  }

  void clear() {
    state = const NotesFilterState();
  }
}

final offlineNoteStoreProvider = Provider<OfflineNoteStore>((ref) {
  final store = OfflineNoteStore();
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

final notesServiceProvider = Provider<NotesService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(firebaseStorageProvider);
  final offlineStore = ref.watch(offlineNoteStoreProvider);
  final service = NotesService(firestore, storage, offlineStore);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final notesSyncProvider = Provider<void>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  final online = ref.watch(isOnlineProvider).asData?.value ?? false;
  if (user != null && online) {
    unawaited(ref.read(notesServiceProvider).synchronize(user.uid));
  }
});

final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  ref.watch(notesSyncProvider);

  final authState = ref.watch(authStateChangesProvider);
  final notesService = ref.watch(notesServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <Note>[]);
      }

      return notesService.watchNotes(user.uid);
    },
    loading: () => Stream.value(const <Note>[]),
    error: (_, _) => Stream.value(const <Note>[]),
  );
});

final notesFilterProvider =
    NotifierProvider<NotesFilterNotifier, NotesFilterState>(
      NotesFilterNotifier.new,
    );

final allNoteTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(notesStreamProvider).asData?.value ?? const <Note>[];
  final tags = <String>{};

  for (final note in notes) {
    tags.addAll(note.tags);
  }

  final sortedTags = tags.toList()..sort();
  return sortedTags;
});

final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(notesStreamProvider).asData?.value ?? const <Note>[];
  final filter = ref.watch(notesFilterProvider);

  if (!filter.hasActiveFilters) {
    return notes;
  }

  return notes.where((note) {
    final noteTags = note.tags.toSet();
    final matchesTags = filter.selectedTags.every(noteTags.contains);
    final matchesColor =
        filter.selectedColor == null ||
        note.color.toRadixString(16).toUpperCase() == filter.selectedColor;
    final query = filter.searchQuery.trim().toLowerCase();
    final title = note.title?.toLowerCase() ?? '';
    final content = note.content.toLowerCase();
    final matchesSearch =
        query.isEmpty || title.contains(query) || content.contains(query);

    return matchesSearch && matchesTags && matchesColor;
  }).toList()..sort((a, b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }

    final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
    if (updatedCompare != 0) {
      return updatedCompare;
    }

    return b.createdAt.compareTo(a.createdAt);
  });
});
