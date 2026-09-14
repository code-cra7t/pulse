import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/personal_graph/data/explicit_graph_fact_parser.dart';

void main() {
  const parser = ExplicitGraphFactParser();
  final now = DateTime(2026, 9, 14, 9);

  test('parses only explicit Person, Decision, and Event markers', () {
    final note = _note(
      now,
      content: '''
People: Sarah Jones, Michael Chen
Decision: Use Flutter for the client app
Event: 2026-09-18 | Architecture review
Alice will probably join later.
''',
    );

    final facts = parser.parse(note);

    expect(facts.people.map((item) => item.label), [
      'Sarah Jones',
      'Michael Chen',
    ]);
    expect(facts.decisions.single.label, 'Use Flutter for the client app');
    expect(facts.events.single.label, 'Architecture review');
    expect(facts.events.single.startsAt, DateTime(2026, 9, 18));
    expect(
      facts.people.any((item) => item.label == 'Alice'),
      isFalse,
      reason: 'Ordinary prose must never become a graph entity.',
    );
  });

  test(
    'supports bullet markers and deduplicates people case-insensitively',
    () {
      final note = _note(
        now,
        content: '''
- Person: Sarah Jones
* People: sarah   jones; Michael Chen
• Decision: Keep review-first graph facts
''',
      );

      final facts = parser.parse(note);

      expect(facts.people, hasLength(2));
      expect(
        facts.people.map((item) => item.entityId),
        containsAll(['sarah jones', 'michael chen']),
      );
      expect(facts.decisions.single.label, 'Keep review-first graph facts');
    },
  );

  test('ignores empty, malformed, and oversized markers', () {
    final note = _note(
      now,
      content: [
        'Person:',
        'Decision',
        'Event: ',
        'Person: ${'x' * 121}',
        'Decision: ${'y' * 501}',
      ].join('\n'),
    );

    final facts = parser.parse(note);

    expect(facts.isEmpty, isTrue);
  });
}

Note _note(DateTime now, {required String content}) {
  return Note(
    id: 'note-1',
    userId: 'user-1',
    title: 'Graph facts',
    isPinned: false,
    createdAt: now,
    updatedAt: now,
    tags: const [],
    content: content,
    color: 0,
    images: const [],
  );
}
