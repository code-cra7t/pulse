import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/capture/presentation/natural_language_capture_sheet.dart';

void main() {
  testWidgets('capture preview remains usable at 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: NaturalLanguageCaptureSheet()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('natural-language-capture-field')),
      'Life insurance exam Oct 2. Revise 8 chapters and do two mock exams.',
    );
    await tester.pump();

    expect(find.text('JotCue found a Project'), findsOneWidget);
    expect(find.text('Life insurance exam'), findsOneWidget);
    expect(find.text('Revise 8 chapters'), findsOneWidget);
    expect(find.text('Do two mock exams'), findsOneWidget);
    expect(find.text('Create project + tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguous capture offers note fallback instead of guessing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(body: NaturalLanguageCaptureSheet()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('natural-language-capture-field')),
      'I am thinking about a few things for later.',
    );
    await tester.pump();

    expect(find.text('Keep this as a note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-structured-capture')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('save-capture-as-note')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
