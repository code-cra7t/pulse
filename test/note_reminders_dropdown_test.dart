import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/notes/models/note.dart';
import 'package:pulse/features/reminders/models/repeat_type.dart';
import 'package:pulse/features/reminders/presentation/note_reminders_sheet.dart';
import 'package:pulse/features/reminders/providers/reminders_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const captureUi = bool.fromEnvironment('CAPTURE_UI');
  setUpAll(() async {
    if (captureUi) {
      final bytes = await File(r'C:\Windows\Fonts\arial.ttf').readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      final icons = await File(
        r'C:\src\flutter\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    }
  });
  final note = Note(
    id: 'visual-note',
    userId: 'visual-user',
    title: 'Visual reminder fixture',
    isPinned: false,
    createdAt: DateTime(2026, 8, 15, 10, 30),
    updatedAt: DateTime(2026, 8, 15, 10, 30),
    tags: const [],
    content: 'Check the reminder menu contrast.',
    color: 0xFFFFF8E1,
    images: const [],
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ThemeData theme,
    required String screenshotName,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRemindersStreamProvider(
            note.id,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: captureUi
              ? theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
                )
              : theme,
          home: Scaffold(body: NoteRemindersSheet(note: note)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<RepeatType>));
    await tester.pumpAndSettle();

    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Every week'), findsOneWidget);
    expect(find.text('Custom interval'), findsOneWidget);
    for (final label in ['Every day', 'Every week', 'Custom interval']) {
      final labelFinder = find.text(label);
      final labelElement = tester.element(labelFinder);
      final textColor = DefaultTextStyle.of(labelElement).style.color;
      final popupColor =
          tester
              .widget<DropdownButton<RepeatType>>(
                find.byType(DropdownButton<RepeatType>),
              )
              .dropdownColor ??
          theme.canvasColor;
      expect(textColor, isNotNull);
      expect(_contrastRatio(textColor!, popupColor), greaterThanOrEqualTo(4.5));
      expect(tester.getRect(labelFinder).bottom, lessThanOrEqualTo(844));
    }

    if (captureUi) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/verification/$screenshotName.png'),
      );
    }
  }

  testWidgets('repeat dropdown is readable and bounded in light mode', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      theme: AppTheme.build(),
      screenshotName: 'reminders-repeat-light',
    );
  });

  testWidgets('repeat dropdown is readable and bounded in dark mode', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      theme: AppTheme.buildDark(),
      screenshotName: 'reminders-repeat-dark',
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final high = lighter > darker ? lighter : darker;
  final low = lighter > darker ? darker : lighter;
  return (high + 0.05) / (low + 0.05);
}
