import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/notes/models/note_category.dart';
import 'package:pulse/features/notes/providers/note_draft_controller.dart';

void main() {
  test(
    'draft saves title, body, category, images, and color together',
    () async {
      NoteDraft? savedDraft;
      final controller = NoteDraftController(
        initialDraft: NoteDraft(
          noteId: 'note-1',
          title: '',
          body: '',
          category: null,
          imageUrls: const [],
          color: 0xFFFFF8E1,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        save: (draft) async {
          savedDraft = draft;
          return NoteDraftSaveResult(
            noteId: 'note-1',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026, 1, 2),
          );
        },
        debounceDuration: const Duration(hours: 1),
      );

      controller.updateTitle('Trip');
      controller.updateBody('Pack camera');
      controller.updateCategory('Personal');
      controller.updateColor(0xFFE1F5FE);
      controller.updateImages(const ['https://example.test/image.jpg']);

      expect(await controller.saveNow(), isTrue);
      expect(savedDraft?.title, 'Trip');
      expect(savedDraft?.body, 'Pack camera');
      expect(savedDraft?.category, 'Personal');
      expect(savedDraft?.color, 0xFFE1F5FE);
      expect(savedDraft?.imageUrls, ['https://example.test/image.jpg']);
      expect(controller.status, NoteSaveStatus.saved);

      controller.dispose();
    },
  );

  test('draft exposes failed saves without discarding local changes', () async {
    final controller = NoteDraftController(
      initialDraft: NoteDraft(
        noteId: 'note-1',
        title: '',
        body: '',
        category: null,
        imageUrls: const [],
        color: 0xFFFFF8E1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      save: (_) => Future<NoteDraftSaveResult>.error(StateError('offline')),
      debounceDuration: const Duration(hours: 1),
    );

    controller.updateBody('Unsaved but still here');

    expect(await controller.saveNow(), isFalse);
    expect(controller.status, NoteSaveStatus.failed);
    expect(controller.hasUnsavedChanges, isTrue);
    expect(controller.draft.body, 'Unsaved but still here');

    controller.dispose();
  });

  test('same-value updates do not mark clean drafts dirty', () async {
    var saveCount = 0;
    final controller = NoteDraftController(
      initialDraft: NoteDraft(
        noteId: 'note-1',
        title: 'Trip',
        body: 'Pack camera',
        category: 'Personal',
        imageUrls: const ['https://example.test/image.jpg'],
        color: 0xFFE1F5FE,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      save: (draft) async {
        saveCount++;
        return NoteDraftSaveResult(
          noteId: draft.noteId!,
          createdAt: draft.createdAt!,
          updatedAt: DateTime(2026, 1, 2),
        );
      },
    );

    controller.updateTitle('Trip');
    controller.updateBody('Pack camera');
    controller.updateCategory('Personal');
    controller.updateColor(0xFFE1F5FE);
    controller.updateImages(const ['https://example.test/image.jpg']);

    expect(controller.hasUnsavedChanges, isFalse);
    expect(await controller.saveNow(), isTrue);
    expect(saveCount, 0);

    controller.dispose();
  });

  test('default categories normalize case-insensitively', () {
    expect(NoteCategory.normalize('work'), 'Work');
    expect(NoteCategory.normalize('TO-DO'), 'To-Do');
    expect(NoteCategory.fromTags(['urgent', 'study']), 'Study');
  });
}
