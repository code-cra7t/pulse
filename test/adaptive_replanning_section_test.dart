import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/scheduling/models/replanning_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/presentation/widgets/adaptive_replanning_section.dart';

void main() {
  testWidgets('replanning review actions fit at 320 px', (tester) async {
    final block = ScheduleBlock(
      id: 'past',
      userId: 'user',
      taskId: 'task',
      title: 'A fairly long planned study session title',
      startsAt: DateTime(2026, 9, 14, 9),
      endsAt: DateTime(2026, 9, 14, 10),
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    );
    final overview = ReplanningOverview(
      generatedAt: DateTime(2026, 9, 14, 12),
      horizonEnd: DateTime(2026, 9, 20, 20),
      calendarConflictsChecked: true,
      issues: [
        ReplanningIssue(
          id: 'past',
          kind: ReplanningIssueKind.pastBlockReview,
          title: block.title,
          message: 'This planned block has passed.',
          taskId: block.taskId,
          block: block,
          suggestion: ReplanningSuggestion(
            startsAt: DateTime(2026, 9, 14, 14),
            endsAt: DateTime(2026, 9, 14, 15),
          ),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdaptiveReplanningSection(
                state: AsyncData(overview),
                onMove: (_) {},
                onMarkCompleted: (_) {},
                onMarkMissed: (_) {},
                onRemove: (_) {},
                onReviewTask: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('urgent capacity issue exposes task review without move action', (
    tester,
  ) async {
    final overview = ReplanningOverview(
      generatedAt: DateTime(2026, 9, 14, 12),
      horizonEnd: DateTime(2026, 9, 20, 20),
      calendarConflictsChecked: false,
      issues: const [
        ReplanningIssue(
          id: 'urgent-task',
          kind: ReplanningIssueKind.urgentCapacity,
          title: 'Finish deadline work',
          message:
              'About 1h of this task still cannot fit before its deadline.',
          taskId: 'task',
          remainingMinutes: 60,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveReplanningSection(
              state: AsyncData(overview),
              onMove: (_) {},
              onMarkCompleted: (_) {},
              onMarkMissed: (_) {},
              onRemove: (_) {},
              onReviewTask: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Review task'), findsOneWidget);
    expect(find.text('Move'), findsNothing);
  });
}
