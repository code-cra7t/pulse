import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/auth/presentation/welcome_screen.dart';

void main() {
  testWidgets('keeps the note-stack concept and exposes both auth paths', (
    tester,
  ) async {
    var started = false;
    var signedIn = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: WelcomeScreen(
          onStart: () => started = true,
          onSignIn: () => signedIn = true,
        ),
      ),
    );

    expect(find.text('JotCue'), findsOneWidget);
    expect(find.text('Write it down.\nWe’ll cue the rest.'), findsOneWidget);
    expect(find.text('Meeting notes'), findsOneWidget);
    expect(find.text('Home reset'), findsOneWidget);
    expect(find.text('Call Mike at 5pm'), findsOneWidget);

    await tester.tap(find.text('Start writing'));
    expect(started, isTrue);

    await tester.ensureVisible(find.text('I already have an account'));
    await tester.tap(find.text('I already have an account'));
    expect(signedIn, isTrue);
  });
}
