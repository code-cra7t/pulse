import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/assistant/data/assistant_account_guard.dart';
import 'package:pulse/features/assistant/data/voice_input_service.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/assistant/presentation/ask_jotcue_sheet.dart';
import 'package:pulse/features/assistant/providers/assistant_providers.dart';
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
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
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
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
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
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
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
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
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
            assistantAccountGuardProvider.overrideWithValue(
              AssistantAccountGuard(currentUserId: () => 'user'),
            ),
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

  testWidgets('voice transcript stays editable and never auto-submits', (
    tester,
  ) async {
    final voice = _FakeVoiceInputService();
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
          voiceInputServiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(assistantContext: assistantContext()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ask-jotcue-voice')));
    await tester.pump();
    expect(voice.starts, [VoiceRecognitionMode.onDevice]);

    voice.emitTranscript('Add task Buy groceries', isFinal: true);
    voice.finishListening();
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('ask-jotcue-field')),
    );
    expect(field.controller?.text, 'Add task Buy groceries');
    expect(field.readOnly, isFalse);
    expect(find.text('Create task'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('ask-jotcue-field')),
      'Add task Buy groceries by Friday',
    );
    await tester.tap(find.byKey(const ValueKey('ask-jotcue-send')));
    await tester.pumpAndSettle();

    expect(find.text('Create task'), findsOneWidget);
  });

  testWidgets('system speech fallback is separately disclosed and approved', (
    tester,
  ) async {
    final voice = _FakeVoiceInputService();
    addTearDown(voice.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
          voiceInputServiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(assistantContext: assistantContext()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ask-jotcue-voice')));
    await tester.pump();
    voice.failOnDevice();
    await tester.pump();

    expect(find.text('Use system speech'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ask-jotcue-system-voice')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('may use an online speech-recognition service'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Use system speech'));
    await tester.pump();
    expect(voice.starts, [
      VoiceRecognitionMode.onDevice,
      VoiceRecognitionMode.system,
    ]);
  });

  testWidgets('suggest mode shows a bounded multi-step plan preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tasks = [
      Task(
        id: 'chapter',
        userId: 'user',
        title: 'Revise chapter 4',
        isCompleted: false,
        sourceNoteId: 'note-1',
        sourceLineIndex: 0,
      ),
      Task(
        id: 'summary',
        userId: 'user',
        title: 'Write summary',
        isCompleted: false,
        sourceNoteId: 'note-2',
        sourceLineIndex: 0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
          automationPreferencesProvider.overrideWith(
            (ref) =>
                const AutomationPreferences(level: AutomationLevel.suggest),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: AskJotCueSheet(
              assistantContext: assistantContext(tasks: tasks),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('ask-jotcue-field')),
      'First mark Revise chapter 4 done, then set Write summary priority to high',
    );
    await tester.tap(find.byKey(const ValueKey('ask-jotcue-send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Multi-step plan preview'), findsOneWidget);
    expect(find.text('2-step plan'), findsOneWidget);
    expect(find.text('1. Mark complete'), findsOneWidget);
    expect(find.text('2. Change priority'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Suggestion only'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

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
          assistantAccountGuardProvider.overrideWithValue(
            AssistantAccountGuard(currentUserId: () => 'user'),
          ),
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

class _FakeVoiceInputService implements VoiceInputService {
  final StreamController<VoiceInputEvent> _events =
      StreamController<VoiceInputEvent>.broadcast(sync: true);

  final List<VoiceRecognitionMode> starts = <VoiceRecognitionMode>[];
  bool _listening = false;

  @override
  Stream<VoiceInputEvent> get events => _events.stream;

  @override
  bool get isListening => _listening;

  @override
  bool get isPlatformSupported => true;

  @override
  Future<bool> start({required VoiceRecognitionMode mode}) async {
    starts.add(mode);
    _listening = true;
    _events.add(VoiceInputEvent.listening(true));
    return true;
  }

  void emitTranscript(String text, {required bool isFinal}) {
    _events.add(VoiceInputEvent.transcript(text, isFinal: isFinal));
  }

  void finishListening() {
    _listening = false;
    _events.add(VoiceInputEvent.listening(false));
  }

  void failOnDevice() {
    _listening = false;
    _events.add(
      VoiceInputEvent.error(
        'On-device speech recognition is unavailable for this language or device.',
        canRetryWithSystem: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    finishListening();
  }

  @override
  Future<void> cancel() async {
    if (_listening) finishListening();
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}
