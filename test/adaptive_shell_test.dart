import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/widgets/adaptive_shell.dart';
import 'package:pulse/core/widgets/pulse_components.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          onCreate: () {},
          profileName: 'JotCue User',
          body: const Center(child: Text('Main content')),
          desktopList: const Center(child: Text('Desktop notes list')),
          desktopEditor: const Center(child: Text('Desktop editor')),
        ),
      ),
    );
  }

  testWidgets('mobile uses bottom navigation', (tester) async {
    await pumpShell(tester, 600);

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.text('Main content'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('narrow mobile navigation prioritizes icons', (tester) async {
    await pumpShell(tester, 320);

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet uses sidebar with main content', (tester) async {
    await pumpShell(tester, 900);

    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(find.text('Main content'), findsOneWidget);
    expect(find.byTooltip('Today'), findsOneWidget);
    expect(find.text('Desktop editor'), findsNothing);
  });

  testWidgets('desktop uses sidebar, list, and editor panes', (tester) async {
    await pumpShell(tester, 1400);

    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Desktop notes list'), findsOneWidget);
    expect(find.text('Desktop editor'), findsOneWidget);
  });

  testWidgets('desktop can show a single workspace beside the sidebar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveShell(
          selectedIndex: 2,
          onDestinationSelected: (_) {},
          onCreate: () {},
          profileName: 'JotCue User',
          body: const Center(child: Text('Mobile plan')),
          desktopList: const Center(child: Text('Desktop notes list')),
          desktopEditor: const Center(child: Text('Desktop editor')),
          desktopWorkspace: const Center(child: Text('Plan workspace')),
        ),
      ),
    );

    expect(find.text('Plan workspace'), findsOneWidget);
    expect(find.text('Desktop notes list'), findsNothing);
    expect(find.text('Desktop editor'), findsNothing);
    expect(find.text('Plan'), findsOneWidget);
  });

  testWidgets('minimum desktop width does not squeeze panes', (tester) async {
    await pumpShell(tester, 1100);

    expect(find.text('JotCue'), findsOneWidget);
    expect(find.text('Desktop notes list'), findsOneWidget);
    expect(find.text('Desktop editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
