import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/offline/offline_note_store.dart';
import 'package:pulse/core/offline/pending_note_mutation.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late OfflineNoteStore store;

  setUp(() {
    final databaseName =
        'pulsenotes-test-${DateTime.now().microsecondsSinceEpoch}.db';
    store = OfflineNoteStore(
      openDatabase: () => databaseFactoryMemory.openDatabase(databaseName),
    );
  });

  tearDown(() async {
    await store.dispose();
  });

  test(
    'stages note changes locally and collapses repeated mutations',
    () async {
      final note = _note(content: 'First');
      final firstMutation = _upsertMutation('mutation-1', note);

      await store.stageUpsert(note, firstMutation);

      expect(await store.readNotes(note.userId), [hasContent('First')]);
      expect(await store.pendingMutations(note.userId), hasLength(1));

      final updated = note.copyWith(
        content: 'Second',
        updatedAt: note.updatedAt.add(const Duration(minutes: 1)),
      );
      await store.stageUpsert(updated, _upsertMutation('mutation-2', updated));

      final pending = await store.pendingMutations(note.userId);
      expect(await store.readNotes(note.userId), [hasContent('Second')]);
      expect(pending, hasLength(1));
      expect(pending.single.id, 'mutation-2');
    },
  );

  test('remote merge does not overwrite a pending local edit', () async {
    final local = _note(content: 'Local edit');
    await store.stageUpsert(local, _upsertMutation('mutation-1', local));

    final remote = local.copyWith(
      content: 'Remote edit',
      updatedAt: local.updatedAt.add(const Duration(minutes: 1)),
    );
    await store.mergeRemoteNotes(local.userId, [remote]);

    expect(await store.readNotes(local.userId), [hasContent('Local edit')]);

    await store.removeMutation('mutation-1');
    await store.mergeRemoteNotes(local.userId, [remote]);

    expect(await store.readNotes(local.userId), [hasContent('Remote edit')]);
  });

  test(
    'stages an offline delete and keeps it deleted during remote merge',
    () async {
      final note = _note(content: 'Delete me');
      await store.stageUpsert(note, _upsertMutation('mutation-1', note));

      final deleteMutation = PendingNoteMutation(
        id: 'mutation-2',
        userId: note.userId,
        noteId: note.id,
        type: PendingNoteMutationType.delete,
        payload: null,
        createdAt: DateTime(2026, 1, 2),
      );
      await store.stageDelete(note.userId, note.id, deleteMutation);
      await store.mergeRemoteNotes(note.userId, [note]);

      expect(await store.readNotes(note.userId), isEmpty);
      final pending = await store.pendingMutations(note.userId);
      expect(pending.single.type, PendingNoteMutationType.delete);
    },
  );

  test('clears cached notes and mutations for only the selected user', () async {
    final first = _note(content: 'First user');
    final second = Note(
      id: 'note-2',
      userId: 'user-2',
      title: 'Other note',
      isPinned: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      tags: const [],
      content: 'Second user',
      color: 0xFFFFF8E1,
      images: const [],
    );

    await store.stageUpsert(first, _upsertMutation('mutation-1', first));
    await store.stageUpsert(second, _upsertMutation('mutation-2', second));
    await store.clearUser(first.userId);

    expect(await store.readNotes(first.userId), isEmpty);
    expect(await store.pendingMutations(first.userId), isEmpty);
    expect(await store.readNotes(second.userId), hasLength(1));
    expect(await store.pendingMutations(second.userId), hasLength(1));
  });
}

Note _note({required String content}) {
  return Note(
    id: 'note-1',
    userId: 'user-1',
    title: 'Test note',
    isPinned: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    tags: const ['Personal'],
    content: content,
    color: 0xFFFFF8E1,
    images: const [],
  );
}

PendingNoteMutation _upsertMutation(String id, Note note) {
  return PendingNoteMutation(
    id: id,
    userId: note.userId,
    noteId: note.id,
    type: PendingNoteMutationType.upsert,
    payload: note.toLocalMap(),
    createdAt: note.updatedAt,
  );
}

Matcher hasContent(String content) {
  return isA<Note>().having((note) => note.content, 'content', content);
}
