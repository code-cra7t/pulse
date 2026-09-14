import '../../notes/models/note.dart';

class ExplicitGraphPersonFact {
  const ExplicitGraphPersonFact({
    required this.entityId,
    required this.label,
    required this.lineIndex,
  });

  final String entityId;
  final String label;
  final int lineIndex;
}

class ExplicitGraphDecisionFact {
  const ExplicitGraphDecisionFact({
    required this.entityId,
    required this.label,
    required this.lineIndex,
  });

  final String entityId;
  final String label;
  final int lineIndex;
}

class ExplicitGraphEventFact {
  const ExplicitGraphEventFact({
    required this.entityId,
    required this.label,
    required this.lineIndex,
    this.startsAt,
  });

  final String entityId;
  final String label;
  final int lineIndex;
  final DateTime? startsAt;
}

class ExplicitNoteGraphFacts {
  const ExplicitNoteGraphFacts({
    this.people = const <ExplicitGraphPersonFact>[],
    this.decisions = const <ExplicitGraphDecisionFact>[],
    this.events = const <ExplicitGraphEventFact>[],
  });

  final List<ExplicitGraphPersonFact> people;
  final List<ExplicitGraphDecisionFact> decisions;
  final List<ExplicitGraphEventFact> events;

  bool get isEmpty => people.isEmpty && decisions.isEmpty && events.isEmpty;
}

/// Reads only explicit, user-visible Personal Graph markers from Note content.
///
/// Supported marker lines:
/// - `Person: Sarah Jones`
/// - `People: Sarah Jones, Michael Chen`
/// - `Decision: Use Flutter for the client app`
/// - `Event: Architecture review`
/// - `Event: 2026-09-18 | Architecture review`
///
/// Ordinary prose is deliberately ignored. This parser never performs entity
/// inference and never persists anything; the Note remains the source of truth.
class ExplicitGraphFactParser {
  const ExplicitGraphFactParser();

  static const int _maxPersonLength = 120;
  static const int _maxFactLength = 500;

  ExplicitNoteGraphFacts parse(Note note) {
    final peopleById = <String, ExplicitGraphPersonFact>{};
    final decisions = <ExplicitGraphDecisionFact>[];
    final events = <ExplicitGraphEventFact>[];

    final lines = note.content.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = _stripBullet(lines[index].trim());
      if (line.isEmpty) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex <= 0) continue;

      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      if (value.isEmpty) continue;

      switch (key) {
        case 'person':
        case 'people':
          for (final rawName in value.split(RegExp(r'[,;]'))) {
            final label = _bounded(rawName.trim(), _maxPersonLength);
            if (label == null) continue;
            final entityId = _personEntityId(label);
            peopleById.putIfAbsent(
              entityId,
              () => ExplicitGraphPersonFact(
                entityId: entityId,
                label: label,
                lineIndex: index,
              ),
            );
          }
          break;
        case 'decision':
          final label = _bounded(value, _maxFactLength);
          if (label == null) continue;
          decisions.add(
            ExplicitGraphDecisionFact(
              entityId: '${note.id}:decision:$index',
              label: label,
              lineIndex: index,
            ),
          );
          break;
        case 'event':
          final parsed = _parseEvent(note.id, value, index);
          if (parsed != null) events.add(parsed);
          break;
      }
    }

    return ExplicitNoteGraphFacts(
      people: List<ExplicitGraphPersonFact>.unmodifiable(peopleById.values),
      decisions: List<ExplicitGraphDecisionFact>.unmodifiable(decisions),
      events: List<ExplicitGraphEventFact>.unmodifiable(events),
    );
  }

  ExplicitGraphEventFact? _parseEvent(
    String noteId,
    String raw,
    int lineIndex,
  ) {
    var label = raw.trim();
    DateTime? startsAt;

    final separator = label.indexOf('|');
    if (separator > 0) {
      final possibleDate = label.substring(0, separator).trim();
      final parsedDate = DateTime.tryParse(possibleDate);
      final possibleLabel = label.substring(separator + 1).trim();
      if (parsedDate != null && possibleLabel.isNotEmpty) {
        startsAt = parsedDate;
        label = possibleLabel;
      }
    }

    final bounded = _bounded(label, _maxFactLength);
    if (bounded == null) return null;

    return ExplicitGraphEventFact(
      entityId: '$noteId:event:$lineIndex',
      label: bounded,
      lineIndex: lineIndex,
      startsAt: startsAt,
    );
  }

  String _stripBullet(String line) {
    if (line.startsWith('- ') ||
        line.startsWith('* ') ||
        line.startsWith('• ')) {
      return line.substring(2).trimLeft();
    }
    return line;
  }

  String? _bounded(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || normalized.length > maxLength) return null;
    return normalized;
  }

  String _personEntityId(String label) {
    return label.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }
}
