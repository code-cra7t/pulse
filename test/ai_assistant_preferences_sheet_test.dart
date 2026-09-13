import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/assistant/models/ai_assistant_preferences.dart';
import 'package:pulse/features/assistant/presentation/ai_assistant_preferences_sheet.dart';

void main() {
  testWidgets('AI preferences sheet fits 320px and can select hybrid', (
    tester,
  ) async {
    AiAssistantPreferences? result;
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAiAssistantPreferencesSheet(
                  context: context,
                  initial: const AiAssistantPreferences(),
                  gatewayConfigured: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('AI assistance'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    expect(find.text('Hybrid'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Hybrid'));
    await tester.pumpAndSettle();
    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result?.mode, AiAssistantMode.hybrid);
  });
}
