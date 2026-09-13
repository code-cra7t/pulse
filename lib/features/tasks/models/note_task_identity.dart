import '../../../core/models/priority_level.dart';

class NoteTaskIdentity {
  const NoteTaskIdentity({
    required this.id,
    required this.lineIndex,
    required this.text,
    this.projectId,
    this.dueAt,
    this.priority = PriorityLevel.none,
    this.estimatedMinutes,
    this.isFlexible = true,
    this.dependsOnTaskIds = const <String>[],
    this.waitingFor,
    this.extraFields = const <String, dynamic>{},
  });

  final String id;
  final int lineIndex;
  final String text;
  final String? projectId;
  final DateTime? dueAt;
  final PriorityLevel priority;
  final int? estimatedMinutes;
  final bool isFlexible;
  final List<String> dependsOnTaskIds;
  final String? waitingFor;

  /// Unknown identity fields are retained so an older modern client does not
  /// erase metadata introduced by a newer schema when it edits the same Task.
  final Map<String, dynamic> extraFields;

  String get normalizedText => normalizeTaskIdentityText(text);

  bool matchesText(String value) {
    return normalizedText == normalizeTaskIdentityText(value);
  }

  factory NoteTaskIdentity.fromMap(Map<String, dynamic> data) {
    final extras = <String, dynamic>{};
    for (final entry in data.entries) {
      if (!_knownFields.contains(entry.key)) {
        extras[entry.key] = entry.value;
      }
    }
    return NoteTaskIdentity(
      id: data['id'] as String? ?? '',
      lineIndex: data['lineIndex'] as int? ?? -1,
      text: data['text'] as String? ?? '',
      projectId: data['projectId'] as String?,
      dueAt: _dateFromMilliseconds(data['dueAtMs']),
      priority: PriorityLevel.fromValue(data['priority'] as String?),
      estimatedMinutes: data['estimatedMinutes'] as int?,
      isFlexible: data['isFlexible'] as bool? ?? true,
      dependsOnTaskIds: _stringList(data['dependsOnTaskIds']),
      waitingFor: _normalizedNullableString(data['waitingFor']),
      extraFields: Map<String, dynamic>.unmodifiable(extras),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      ...extraFields,
      'id': id,
      'lineIndex': lineIndex,
      'text': text,
      'projectId': projectId,
      'dueAtMs': dueAt?.millisecondsSinceEpoch,
      'priority': priority.name,
      'estimatedMinutes': estimatedMinutes,
      'isFlexible': isFlexible,
      'dependsOnTaskIds': dependsOnTaskIds,
      'waitingFor': waitingFor,
    };
  }

  NoteTaskIdentity copyWith({
    String? id,
    int? lineIndex,
    String? text,
    Object? projectId = _unchanged,
    Object? dueAt = _unchanged,
    PriorityLevel? priority,
    Object? estimatedMinutes = _unchanged,
    bool? isFlexible,
    List<String>? dependsOnTaskIds,
    Object? waitingFor = _unchanged,
    Map<String, dynamic>? extraFields,
  }) {
    return NoteTaskIdentity(
      id: id ?? this.id,
      lineIndex: lineIndex ?? this.lineIndex,
      text: text ?? this.text,
      projectId: identical(projectId, _unchanged)
          ? this.projectId
          : projectId as String?,
      dueAt: identical(dueAt, _unchanged) ? this.dueAt : dueAt as DateTime?,
      priority: priority ?? this.priority,
      estimatedMinutes: identical(estimatedMinutes, _unchanged)
          ? this.estimatedMinutes
          : estimatedMinutes as int?,
      isFlexible: isFlexible ?? this.isFlexible,
      dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
      waitingFor: identical(waitingFor, _unchanged)
          ? this.waitingFor
          : waitingFor as String?,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}

String normalizeTaskIdentityText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  final seen = <String>{};
  final result = <String>[];
  for (final item in value) {
    final normalized = item.toString().trim();
    if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized);
  }
  return result;
}

String? _normalizedNullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

DateTime? _dateFromMilliseconds(Object? value) {
  return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}

const _unchanged = Object();

const Set<String> _knownFields = <String>{
  'id',
  'lineIndex',
  'text',
  'projectId',
  'dueAtMs',
  'priority',
  'estimatedMinutes',
  'isFlexible',
  'dependsOnTaskIds',
  'waitingFor',
};
