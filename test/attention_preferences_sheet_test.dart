import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/attention/models/attention_preferences.dart';
import 'package:pulse/features/attention/presentation/attention_preferences_sheet.dart';

void main() {
  testWidgets('proactive attention sheet fits 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showAttentionPreferencesSheet(
                  context: context,
                  initial: const AttentionPreferences(),
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Proactive attention'), findsWidgets);
    expect(find.text('Morning Pulse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
