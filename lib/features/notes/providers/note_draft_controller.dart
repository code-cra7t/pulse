import 'dart:async';

import 'package:flutter/foundation.dart';

enum NoteSaveStatus { idle, saving, saved, failed }

class NoteDraft {
  const NoteDraft({
    required this.noteId,
    required this.title,
    required this.body,
    required this.category,
    required this.imageUrls,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String? noteId;
  final String title;
  final String body;
  final String? category;
  final List<String> imageUrls;
  final int color;
  final DateTime? createdAt;
  final DateTime updatedAt;

  NoteDraft copyWith({
    Object? noteId = _unset,
    String? title,
    String? body,
    Object? category = _unset,
    List<String>? imageUrls,
    int? color,
    Object? createdAt = _unset,
    DateTime? updatedAt,
  }) {
    return NoteDraft(
      noteId: identical(noteId, _unset) ? this.noteId : noteId as String?,
      title: title ?? this.title,
      body: body ?? this.body,
      category: identical(category, _unset)
          ? this.category
          : category as String?,
      imageUrls: imageUrls ?? this.imageUrls,
      color: color ?? this.color,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteDraftSaveResult {
  const NoteDraftSaveResult({
    required this.noteId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String noteId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

typedef NoteDraftSaver = Future<NoteDraftSaveResult> Function(NoteDraft draft);

class NoteDraftController extends ChangeNotifier {
  NoteDraftController({
    required NoteDraft initialDraft,
    required NoteDraftSaver save,
    this.debounceDuration = const Duration(milliseconds: 700),
  }) : _draft = initialDraft,
       _save = save;

  final NoteDraftSaver _save;
  final Duration debounceDuration;

  NoteDraft _draft;
  NoteSaveStatus _status = NoteSaveStatus.idle;
  Object? _lastError;
  Timer? _debounce;
  Future<bool>? _activeSave;
  bool _dirty = false;
  int _revision = 0;

  NoteDraft get draft => _draft;
  NoteSaveStatus get status => _status;
  Object? get lastError => _lastError;
  bool get hasUnsavedChanges => _dirty;

  void updateTitle(String value) {
    if (value == _draft.title) {
      return;
    }
    _update(_draft.copyWith(title: value), immediate: false);
  }

  void updateBody(String value) {
    if (value == _draft.body) {
      return;
    }
    _update(_draft.copyWith(body: value), immediate: false);
  }

  void updateCategory(String? value) {
    if (value == _draft.category) {
      return;
    }
    _update(_draft.copyWith(category: value), immediate: true);
  }

  void updateColor(int value) {
    if (value == _draft.color) {
      return;
    }
    _update(_draft.copyWith(color: value), immediate: true);
  }

  void updateImages(List<String> value) {
    if (_sameStringList(value, _draft.imageUrls)) {
      return;
    }
    _update(
      _draft.copyWith(imageUrls: List.unmodifiable(value)),
      immediate: true,
    );
  }

  void _update(NoteDraft next, {required bool immediate}) {
    _draft = next.copyWith(updatedAt: DateTime.now());
    _dirty = true;
    _revision++;
    _lastError = null;
    _status = NoteSaveStatus.idle;
    notifyListeners();

    _debounce?.cancel();
    if (immediate) {
      unawaited(saveNow());
    } else {
      _debounce = Timer(debounceDuration, () => unawaited(saveNow()));
    }
  }

  Future<bool> saveNow({bool force = false}) async {
    _debounce?.cancel();
    final activeSave = _activeSave;
    if (activeSave != null) {
      final activeSucceeded = await activeSave;
      if (!activeSucceeded) {
        return false;
      }
      return saveNow(force: force && _draft.noteId == null);
    }
    if (force) {
      _dirty = true;
    }
    if (!_dirty) {
      return _status != NoteSaveStatus.failed;
    }

    final save = _performSave();
    _activeSave = save;
    final succeeded = await save;
    if (identical(_activeSave, save)) {
      _activeSave = null;
    }

    if (succeeded && _dirty) {
      return saveNow();
    }
    return succeeded;
  }

  Future<bool> flushPendingSave() {
    return saveNow();
  }

  Future<bool> _performSave() async {
    final snapshot = _draft;
    final savedRevision = _revision;
    _status = NoteSaveStatus.saving;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _save(snapshot);
      _draft = _draft.copyWith(
        noteId: result.noteId,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
      if (_revision == savedRevision) {
        _dirty = false;
      }
      _status = NoteSaveStatus.saved;
      notifyListeners();
      return true;
    } catch (error) {
      _dirty = true;
      _lastError = error;
      _status = NoteSaveStatus.failed;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

const _unset = Object();

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }

  return true;
}
