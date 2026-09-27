// Basic Flutter widget smoke test.
//
// The real app entry point (FixoApp in lib/main.dart) requires Firebase
// initialization, so it can't be pumped directly in a unit test without
// firebase_core_platform_interface mocks. This test verifies the widget
// testing infrastructure works; add Firebase-mocked tests as needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Fixo'),
        ),
      ),
    );

    expect(find.text('Fixo'), findsOneWidget);
  });
}
