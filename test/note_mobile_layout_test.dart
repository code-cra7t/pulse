import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/notes/presentation/notes_home_screen.dart';
import 'package:pulse/features/notes/presentation/widgets/mobile_home_screen.dart';
import 'package:pulse/features/reminders/providers/reminders_providers.dart';
import 'package:pulse/features/settings/providers/user_settings_providers.dart';

void main() {
  final note = Note(
    id: 'narrow-note',
    userId: 'user',
    title: 'A note that must remain editable',
    isPinned: false,
    createdAt: DateTime(2026, 9, 12),
    updatedAt: DateTime(2026, 9, 12),
    tags: const ['Personal'],
    content: 'The note body must stay visible on a physical phone.',
    color: 0xFFFFF8E1,
    images: const [],
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('mobile card header fits two-column layout with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildDark(),
        home: Scaffold(
          body: SizedBox(
            width: 190,
            child: MobileNoteCard(
              note: note,
              reminders: const [],
              onOpenNote: () {},
              onTogglePin: () {},
              onManageReminders: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('note editor displays title and body on a narrow dark screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserSettingsProvider.overrideWith((ref) => Stream.value(null)),
          noteRemindersStreamProvider(
            note.id,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildDark(),
          home: Scaffold(
            body: NoteEditorSheet(userId: note.userId, note: note),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(note.title!), findsOneWidget);
    expect(find.text(note.content), findsOneWidget);
  });
}
