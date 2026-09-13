import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_audit_entry.dart';
import 'package:pulse/features/automation/models/automation_safety_preferences.dart';
import 'package:pulse/features/automation/presentation/automation_activity_section.dart';

void main() {
  testWidgets('automation activity stays readable at 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var undoRequested = false;
    final entry = AutomationAuditEntry(
      id: 'audit',
      userId: 'user',
      action: AutomationActionKind.localScheduleMove,
      issueId: 'issue',
      blockId: 'block',
      title: 'A deliberately long flexible study block title',
      reason:
          'Your calendar changed, so JotCue moved this flexible local block to a safer free slot.',
      fromStartsAt: DateTime(2026, 9, 14, 9),
      fromEndsAt: DateTime(2026, 9, 14, 10),
      toStartsAt: DateTime(2026, 9, 14, 11),
      toEndsAt: DateTime(2026, 9, 14, 12),
      executedAt: DateTime(2026, 9, 13, 16),
      status: AutomationAuditStatus.succeeded,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AutomationActivitySection(
              state: AsyncData([entry]),
              safety: const AutomationSafetyPreferences(),
              trustedEnabled: true,
              onTogglePaused: (_) async {},
              onManageSafety: () {},
              onUndo: (_) async {
                undoRequested = true;
              },
              onClearOlderActivity: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Automation activity'), findsOneWidget);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Clear older activity'), findsOneWidget);
    final undo = find.text('Undo move');
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(undoRequested, isTrue);
    expect(tester.takeException(), isNull);
  });
}
