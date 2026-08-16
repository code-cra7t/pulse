import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/notes/presentation/widgets/mobile_home_screen.dart';
import 'package:pulse/features/reminders/models/reminder.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';

void main() {
  final now = DateTime(2026, 8, 15, 10, 30);

  Note note({
    required String id,
    required String title,
    required String content,
    required int color,
    bool isPinned = false,
  }) {
    return Note(
      id: id,
      userId: 'visual-test-user',
      title: title,
      isPinned: isPinned,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
      tags: const [],
      content: content,
      color: color,
      images: const [],
    );
  }

  final notes = [
    note(
      id: 'meeting',
      title: 'Monday planning',
      content: 'Shape the launch story and confirm the final review.',
      color: 0xFFE1F5FE,
      isPinned: true,
    ),
    note(
      id: 'home',
      title: 'Home reset',
      content: '- Clean the kitchen\n- done: Water the plants',
      color: 0xFFE8F5E9,
    ),
    note(
      id: 'ideas',
      title: 'Ideas worth keeping',
      content: 'A quiet capture flow that stays out of the way.',
      color: 0xFFF3E5F5,
    ),
    note(
      id: 'call',
      title: 'Call Mike at 5pm',
      content: 'Share the updated timeline before the end of the day.',
      color: 0xFFFFF8E1,
    ),
  ];

  final reminder = Reminder(
    id: 'reminder',
    userId: 'visual-test-user',
    noteId: 'call',
    taskLineIndex: null,
    notePreview: 'Call Mike at 5pm',
    scheduledAt: now.add(const Duration(hours: 6)),
    isCompleted: false,
    repeat: RepeatType.none,
    notificationId: 1,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MobileHomeScreen(
            notes: notes,
            pinnedNotes: [notes.first],
            remindersByNoteId: {
              reminder.noteId: [reminder],
            },
            searchController: controller,
            selectedFilter: MobileNoteFilter.all,
            onFilterSelected: (_) {},
            onSearchChanged: (_) {},
            onOpenNote: (_) {},
            onTogglePin: (_) {},
            onManageReminders: (_) {},
            onDelete: (_) {},
            onCreate: () {},
            onFilterTap: () {},
            onProfileTap: () {},
            profileName: 'Alex Morgan',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('notes home stays polished on a compact phone', (tester) async {
    await pumpHome(tester, size: const Size(320, 700), theme: AppTheme.build());

    expect(find.textContaining('Alex'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notes home supports a standard phone in dark mode', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(390, 844),
      theme: AppTheme.buildDark(),
    );

    expect(find.text('All notes'), findsOneWidget);
    expect(find.text('Monday planning'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notes home uses available width below tablet breakpoint', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(699, 900), theme: AppTheme.build());

    expect(find.text('4 sorted by recent updates'), findsOneWidget);
    expect(find.text('Sort: Updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
