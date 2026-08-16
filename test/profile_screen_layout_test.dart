import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/services/app_theme.dart';
import 'package:pulse/features/profile/models/user_profile.dart';
import 'package:pulse/features/profile/presentation/profile_screen.dart';

void main() {
  final profile = UserProfile(
    uid: 'profile-layout-user',
    displayName: 'Tori',
    email: 'tori@example.com',
    photoUrl: null,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 15),
  );

  Future<void> pumpProfile(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    bool embedded = false,
    bool hasChanges = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final controller = TextEditingController(text: profile.displayName);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: embedded ? null : AppBar(title: const Text('Profile')),
          body: ProfileDetailsView(
            profile: profile,
            displayNameController: controller,
            embedded: embedded,
            uploadingPhoto: false,
            saveStatus: ProfileSaveStatus.idle,
            hasChanges: hasChanges,
            onClose: () {},
            onUploadPhoto: () {},
            onDisplayNameChanged: (_) {},
            onSave: () {},
            onSignOut: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('profile remains usable on a 320px phone', (tester) async {
    await pumpProfile(
      tester,
      size: const Size(320, 700),
      theme: AppTheme.build(),
    );

    expect(find.text('JotCue account'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Update profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile actions stack cleanly on a standard phone', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      size: const Size(390, 844),
      theme: AppTheme.build(),
      hasChanges: true,
    );

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded desktop profile uses a bounded horizontal layout', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      size: const Size(760, 760),
      theme: AppTheme.buildDark(),
      embedded: true,
    );

    expect(
      find.text('Your JotCue identity and account details.'),
      findsOneWidget,
    );
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.byTooltip('Close profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
