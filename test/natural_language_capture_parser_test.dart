import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/capture/data/natural_language_capture_parser.dart';
import 'package:pulse/features/capture/models/capture_draft.dart';

void main() {
  final parser = NaturalLanguageCaptureParser();
  final now = DateTime(2026, 9, 13, 10);

  test('parses an exam project with deadline and multiple tasks', () {
    final draft = parser.parse(
      'Life insurance exam Oct 2. Revise 8 chapters and do two mock exams.',
      now: now,
    );

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.project);
    expect(draft.projectName, 'Life insurance exam');
    expect(draft.deadline, DateTime(2026, 10, 2, 23, 59));
    expect(draft.tasks, ['Revise 8 chapters', 'Do two mock exams']);
  });

  test('supports day-first absolute dates', () {
    final draft = parser.parse(
      'Visualization oral exam 8 October. Review lectures and practise questions.',
      now: now,
    );

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.project);
    expect(draft.deadline, DateTime(2026, 10, 8, 23, 59));
    expect(draft.tasks, ['Review lectures', 'Practise questions']);
  });

  test('parses a single task with a month deadline', () {
    final draft = parser.parse('Submit HPC report by Sep 30', now: now);

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.task);
    expect(draft.tasks, ['Submit HPC report']);
    expect(draft.deadline, DateTime(2026, 9, 30, 23, 59));
  });

  test('keeps an action-led project keyword as a task', () {
    final draft = parser.parse('Submit assignment by Friday', now: now);

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.task);
    expect(draft.projectName, isNull);
    expect(draft.tasks, ['Submit assignment']);
    expect(draft.deadline, DateTime(2026, 9, 18, 23, 59));
  });

  test('parses tomorrow as an end-of-day deadline', () {
    final draft = parser.parse('Email the professor tomorrow', now: now);

    expect(draft, isNotNull);
    expect(draft!.deadline, DateTime(2026, 9, 14, 23, 59));
    expect(draft.tasks, ['Email the professor']);
  });

  test('parses multiple tasks without inventing a project', () {
    final draft = parser.parse(
      'Send application; call the agency; update portfolio',
      now: now,
    );

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.taskList);
    expect(draft.projectName, isNull);
    expect(draft.tasks, [
      'Send application',
      'Call the agency',
      'Update portfolio',
    ]);
  });

  test('creates a project-only draft for a clear exam statement', () {
    final draft = parser.parse('Life insurance exam October 2', now: now);

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.project);
    expect(draft.projectName, 'Life insurance exam');
    expect(draft.tasks, isEmpty);
  });

  test('next weekday resolves beyond the upcoming occurrence', () {
    final draft = parser.parse('Submit slides by next Friday', now: now);

    expect(draft, isNotNull);
    expect(draft!.deadline, DateTime(2026, 9, 25, 23, 59));
  });

  test('rolls an omitted-year absolute date into the future', () {
    final draft = parser.parse('Submit report by Sep 10', now: now);

    expect(draft, isNotNull);
    expect(draft!.deadline, DateTime(2027, 9, 10, 23, 59));
  });

  test('parses explicit assistant task command', () {
    final draft = parser.parseCommand(
      'Add task Buy groceries by Friday',
      now: now,
    );

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.task);
    expect(draft.tasks, ['Buy groceries']);
    expect(draft.deadline, DateTime(2026, 9, 18, 23, 59));
  });

  test('parses explicit project command with tasks and deadline', () {
    final draft = parser.parseCommand(
      'Create project called Her Rights website with tasks design landing page and create resource directory, due October 5',
      now: now,
    );

    expect(draft, isNotNull);
    expect(draft!.kind, CaptureDraftKind.project);
    expect(draft.projectName, 'Her Rights website');
    expect(draft.tasks, ['Design landing page', 'Create resource directory']);
    expect(draft.deadline, DateTime(2026, 10, 5, 23, 59));
  });

  test('assistant command parser ignores ordinary prose', () {
    expect(
      parser.parseCommand('Write an email to my lecturer', now: now),
      isNull,
    );
  });

  test('does not invent structure from ambiguous prose', () {
    final draft = parser.parse(
      'I have been thinking a lot about what the future should look like.',
      now: now,
    );

    expect(draft, isNull);
  });
}
