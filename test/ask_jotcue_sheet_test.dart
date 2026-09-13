import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/assistant/presentation/ask_jotcue_sheet.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';

void main() {
  const pulse = PulseOverview(
    focusItems: [],
    cues: [],
    upcomingProjects: [],
    openTaskCount: 0,
    overdueCount: 0,
    dueTodayCount: 0,
    focusEstimatedMinutes: 0,
  );

  AskJotCueContext assistantContext() {
    final now = DateTime(2026, 9, 13, 10);
    return AskJotCueContext(
      now: now,
      pulse: pulse,
      dailyLoop: DailyPulseLoop.build(now: now, pulse: pulse, blocks: const []),
      tasks: const [],
      projects: const [],
      blocks: const [],
    );
  }

  testWidgets('Ask JotCue stays usable at 320 px without an avatar bot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(assistantContext: assistantContext()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ask JotCue'), findsOneWidget);
    expect(
      find.text('Read-only planning assistant · on device'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick question produces a deterministic assistant response', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(assistantContext: assistantContext()),
          ),
        ),
      ),
    );

    await tester.tap(find.text('What should I do now?'));
    await tester.pumpAndSettle();

    expect(find.text('What should I do now?'), findsWidgets);
    expect(
      find.textContaining('Nothing is strongly competing'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown typed request explains current capability boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(assistantContext: assistantContext()),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('ask-jotcue-field')),
      'Tell me a joke',
    );
    await tester.tap(find.byKey(const ValueKey('ask-jotcue-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('I don’t safely understand'), findsOneWidget);
    expect(find.textContaining('does not change tasks'), findsOneWidget);
  });
}
