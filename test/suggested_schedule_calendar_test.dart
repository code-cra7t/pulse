import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/calendar/models/availability_summary.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/scheduling_day_state.dart';
import 'package:pulse/features/scheduling/models/scheduling_preferences.dart';
import 'package:pulse/features/scheduling/presentation/widgets/suggested_schedule_section.dart';

void main() {
  testWidgets('linked calendar controls stay usable at 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final date = DateTime(2026, 9, 14);
    final block = ScheduleBlock(
      id: 'block-1',
      userId: 'user',
      taskId: 'task-1',
      title: 'Long insurance exam revision session',
      startsAt: DateTime(2026, 9, 14, 10),
      endsAt: DateTime(2026, 9, 14, 11, 30),
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    );
    final state = SchedulingDayState(
      date: date,
      preferences: SchedulingPreferences.defaults().copyWith(
        isConfigured: true,
        availableWeekdays: const [DateTime.monday],
      ),
      calendarSupported: true,
      calendarAccess: true,
      acceptedBlocks: [block],
      availability: AvailabilitySummary(
        windowStart: DateTime(2026, 9, 14, 8),
        windowEnd: DateTime(2026, 9, 14, 20),
        busyMinutes: 90,
        freeMinutes: 630,
        freeSlots: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuggestedScheduleSection(
              state: AsyncData(state),
              onConfigure: () {},
              onRequestCalendar: () {},
              onAccept: (_) {},
              onRemoveBlock: (_) {},
              calendarWriteSupported: true,
              onCalendarLinked: (_) async => true,
              onAddOrUpdateCalendar: (_) async => true,
              onRemoveCalendar: (_) async => true,
              wasMovedByJotCue: (_) => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Calendar linked'), findsOneWidget);
    expect(find.textContaining('Moved by JotCue'), findsOneWidget);
    expect(find.byTooltip('Calendar options'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Calendar options'));
    await tester.pumpAndSettle();

    expect(find.text('Update calendar entry'), findsOneWidget);
    expect(find.text('Remove from calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
