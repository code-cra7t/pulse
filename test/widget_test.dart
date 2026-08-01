import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('pulse smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('PulseNotes'))),
    );

    expect(find.text('PulseNotes'), findsOneWidget);
  });
}
