import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tasks/models/note_task_identity.dart';

const _unsetTitle = Object();

/// Current hidden Task metadata schema written by this client.
///
/// Legacy Notes may omit these fields and remain readable. Firestore rules use
/// the per-write token to prevent an older client from replacing modern
/// `taskIdentities` with a lossy legacy shape.
const int currentTaskMetadataSchemaVersion = 1;

class Note {
  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.content,
    required this.color,
    required this.images,
    this.taskIdentities = const <NoteTaskIdentity>[],
    this.taskMetadataSchemaVersion = 0,
    this.taskMetadataWriteToken,
  });

  final String id;
  final String userId;
  final String? title;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String content;
  final int color;
  final List<String> images;
  final List<NoteTaskIdentity> taskIdentities;
  final int taskMetadataSchemaVersion;
  final String? taskMetadataWriteToken;

  bool get usesModernTaskMetadata =>
      taskMetadataSchemaVersion >= currentTaskMetadataSchemaVersion &&
      (taskMetadataWriteToken?.trim().isNotEmpty ?? false);

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;
    final createdAt = createdAtTimestamp?.toDate();
    final updatedAt = updatedAtTimestamp?.toDate();

    return Note(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String?,
      isPinned: data['isPinned'] as bool? ?? false,
      createdAt:
          createdAt ?? updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      tags: (data['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      content: data['content'] as String? ?? '',
      color: data['color'] as int? ?? 0xFFFFF8E1,
      images: _readImageUrls(data),
      taskIdentities: _readTaskIdentities(data),
      taskMetadataSchemaVersion: _readNonNegativeInt(
        data['taskMetadataSchemaVersion'],
      ),
      taskMetadataWriteToken: _readNormalizedToken(
        data['taskMetadataWriteToken'],
      ),
    );
  }

  factory Note.fromLocalMap(Map<String, dynamic> data) {
    return Note(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String?,
      isPinned: data['isPinned'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['createdAtMs'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updatedAtMs'] as int? ?? 0,
      ),
      tags: (data['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      content: data['content'] as String? ?? '',
      color: data['color'] as int? ?? 0xFFFFF8E1,
      images: _readImageUrls(data),
      taskIdentities: _readTaskIdentities(data),
      taskMetadataSchemaVersion: _readNonNegativeInt(
        data['taskMetadataSchemaVersion'],
      ),
      taskMetadataWriteToken: _readNormalizedToken(
        data['taskMetadataWriteToken'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'tags': tags,
      'content': content,
      'color': color,
      'images': images,
      'taskIdentities': taskIdentities.map((item) => item.toMap()).toList(),
      if (taskMetadataSchemaVersion > 0 || taskMetadataWriteToken != null) ...{
        'taskMetadataSchemaVersion': taskMetadataSchemaVersion,
        'taskMetadataWriteToken': taskMetadataWriteToken,
      },
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'isPinned': isPinned,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'tags': tags,
      'content': content,
      'color': color,
      'images': images,
      'taskIdentities': taskIdentities.map((item) => item.toMap()).toList(),
      'taskMetadataSchemaVersion': taskMetadataSchemaVersion,
      'taskMetadataWriteToken': taskMetadataWriteToken,
    };
  }

  Note copyWith({
    String? id,
    String? userId,
    Object? title = _unsetTitle,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? content,
    int? color,
    List<String>? images,
    List<NoteTaskIdentity>? taskIdentities,
    int? taskMetadataSchemaVersion,
    Object? taskMetadataWriteToken = _unsetTaskMetadataWriteToken,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: identical(title, _unsetTitle) ? this.title : title as String?,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      color: color ?? this.color,
      images: images ?? this.images,
      taskIdentities: taskIdentities ?? this.taskIdentities,
      taskMetadataSchemaVersion:
          taskMetadataSchemaVersion ?? this.taskMetadataSchemaVersion,
      taskMetadataWriteToken:
          identical(taskMetadataWriteToken, _unsetTaskMetadataWriteToken)
          ? this.taskMetadataWriteToken
          : taskMetadataWriteToken as String?,
    );
  }
}

List<String> _readImageUrls(Map<String, dynamic> data) {
  final urls = <String>{};
  for (final field in const ['images', 'imageUrls']) {
    final value = data[field];
    if (value is Iterable) {
      for (final item in value) {
        final url = item.toString().trim();
        if (url.isNotEmpty) {
          urls.add(url);
        }
      }
    }
  }
  return urls.toList();
}

List<NoteTaskIdentity> _readTaskIdentities(Map<String, dynamic> data) {
  final raw = data['taskIdentities'];
  if (raw is! List) {
    return const <NoteTaskIdentity>[];
  }

  return raw
      .whereType<Map>()
      .map((item) => NoteTaskIdentity.fromMap(Map<String, dynamic>.from(item)))
      .where((identity) => identity.id.isNotEmpty && identity.lineIndex >= 0)
      .toList(growable: false);
}

int _readNonNegativeInt(Object? value) {
  if (value is int && value >= 0) return value;
  return 0;
}

String? _readNormalizedToken(Object? value) {
  final token = value?.toString().trim() ?? '';
  return token.isEmpty ? null : token;
}

const _unsetTaskMetadataWriteToken = Object();
