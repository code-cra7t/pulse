import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';
import 'package:pulse/features/automation/presentation/automation_preferences_sheet.dart';

void main() {
  testWidgets('automation sheet fits 320 px and returns selected level', (
    tester,
  ) async {
    AutomationPreferences? result;
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAutomationPreferencesSheet(
                  context: context,
                  initial: AutomationPreferences.defaults(),
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

    expect(find.text('Assistant permissions'), findsOneWidget);
    expect(find.text('Observe'), findsOneWidget);
    expect(find.text('Suggest'), findsOneWidget);
    expect(find.text('Act with approval'), findsOneWidget);
    expect(find.text('Trusted'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final trusted = find.byKey(const ValueKey('automation-level-trusted'));
    await tester.ensureVisible(trusted);
    await tester.tap(trusted);
    await tester.pumpAndSettle();
    final save = find.text('Save permissions');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(result?.level, AutomationLevel.trusted);
    expect(tester.takeException(), isNull);
  });
}
