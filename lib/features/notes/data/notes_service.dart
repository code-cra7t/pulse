import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/note.dart';
import '../utils/tag_parser.dart';
import '../utils/task_parser.dart';

class NotesService {
  NotesService(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _notesCollection {
    return _firestore.collection('notes');
  }

  Stream<List<Note>> watchNotes(String userId) {
    return _notesCollection.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final notes = snapshot.docs.map(Note.fromFirestore).toList();
      notes.sort((a, b) {
        final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
        if (updatedCompare != 0) {
          return updatedCompare;
        }

        return b.createdAt.compareTo(a.createdAt);
      });
      return notes;
    });
  }

  Future<Note> createNote({
    required String userId,
    String? title,
    bool isPinned = false,
    required String content,
    required int color,
    List<String> images = const [],
  }) async {
    final normalizedContent = TaskParser.normalizeTaskContent(content);
    final tags = TagParser.extractTags(normalizedContent);
    final now = DateTime.now();

    final doc = await _notesCollection.add({
      'userId': userId,
      'title': title,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'tags': tags,
      'content': normalizedContent,
      'color': color,
      'images': images,
    });

    return Note(
      id: doc.id,
      userId: userId,
      title: title,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
      tags: tags,
      content: normalizedContent,
      color: color,
      images: images,
    );
  }

  Future<void> updateNote(Note note) {
    final normalizedContent = TaskParser.normalizeTaskContent(note.content);
    final updatedNote = note.copyWith(
      content: normalizedContent,
      tags: TagParser.extractTags(normalizedContent),
      updatedAt: DateTime.now(),
    );
    return _notesCollection.doc(note.id).update(updatedNote.toMap());
  }

  Future<void> deleteNote(String noteId) {
    return _notesCollection.doc(noteId).delete();
  }

  Future<String> uploadNoteImage({
    required String userId,
    required XFile image,
  }) async {
    final nameParts = image.name.split('.');
    final extension = nameParts.length > 1 ? nameParts.last.toLowerCase() : 'jpg';
    final path =
        'notes/$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final reference = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: image.mimeType);
    final bytes = await image.readAsBytes();
    await reference.putData(bytes, metadata);

    return reference.getDownloadURL();
  }
}
