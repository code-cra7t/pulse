import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/auth/presentation/login_screen.dart';
import 'package:pulse/features/auth/presentation/signup_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size size,
    required Widget screen,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(),
          darkTheme: AppTheme.buildDark(),
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('login stays branded and overflow-free on a phone', (
    tester,
  ) async {
    var wentBack = false;
    await pumpScreen(
      tester,
      size: const Size(390, 844),
      screen: LoginScreen(onBack: () => wentBack = true),
    );

    expect(find.text('JotCue'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsNWidgets(2));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Back'));
    expect(wentBack, isTrue);
  });

  testWidgets('signup stays usable on a compact phone', (tester) async {
    await pumpScreen(
      tester,
      size: const Size(320, 700),
      screen: const SignupScreen(),
    );

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login remains focused at desktop width', (tester) async {
    await pumpScreen(
      tester,
      size: const Size(1440, 900),
      screen: const LoginScreen(),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
