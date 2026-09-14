import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/assistant/presentation/ask_jotcue_sheet.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';
import 'package:pulse/features/automation/providers/automation_providers.dart';
import 'package:pulse/features/tasks/models/task.dart';
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

  AskJotCueContext assistantContext({List<Task> tasks = const <Task>[]}) {
    final now = DateTime(2026, 9, 13, 10);
    return AskJotCueContext(
      now: now,
      userId: 'user',
      pulse: pulse,
      dailyLoop: DailyPulseLoop.build(now: now, pulse: pulse, blocks: const []),
      tasks: tasks,
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
        overrides: [
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
        ],
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
    expect(find.text('Planning assistant · on device'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick question produces a deterministic assistant response', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
        ],
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
        overrides: [
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
        ],
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
    expect(
      find.textContaining('Unsupported requests never change anything'),
      findsOneWidget,
    );
  });

  testWidgets('suggest mode shows action preview but keeps Apply disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final task = Task(
      id: 'task',
      userId: 'user',
      title: 'Revise chapter 4',
      isCompleted: false,
      sourceNoteId: 'note',
      sourceLineIndex: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(
              assistantContext: assistantContext(tasks: [task]),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('ask-jotcue-field')),
      'Mark Revise chapter 4 done',
    );
    await tester.tap(find.byKey(const ValueKey('ask-jotcue-send')));
    await tester.pumpAndSettle();

    expect(find.text('Mark complete'), findsOneWidget);
    expect(find.text('Suggestion only'), findsWidgets);
    final apply = tester.widget<FilledButton>(
      find.byKey(const ValueKey('ask-jotcue-apply-completion:task:true')),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets(
    'capture request shows reviewed creation preview in suggest mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationPreferencesProvider.overrideWith(
              (ref) =>
                  const AutomationPreferences(level: AutomationLevel.suggest),
            ),
          ],
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
        'Add task Buy groceries by Friday',
      );
      await tester.tap(find.byKey(const ValueKey('ask-jotcue-send')));
      await tester.pumpAndSettle();

      expect(find.text('Create task'), findsOneWidget);
      expect(find.textContaining('Buy groceries'), findsWidgets);
      expect(find.text('Suggestion only'), findsWidgets);
    },
  );

  testWidgets('observe mode explains boundary without exposing action card', (
    tester,
  ) async {
    final task = Task(
      id: 'task',
      userId: 'user',
      title: 'Revise chapter 4',
      isCompleted: false,
      sourceNoteId: 'note',
      sourceLineIndex: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.observe),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(
              assistantContext: assistantContext(tasks: [task]),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('ask-jotcue-field')),
      'Mark Revise chapter 4 done',
    );
    await tester.tap(find.byKey(const ValueKey('ask-jotcue-send')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Observe mode does not prepare'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ask-jotcue-action-completion:task:true')),
      findsNothing,
    );
  });
}
