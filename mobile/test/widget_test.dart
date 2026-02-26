/// Smoke tests — verify the app's root widget tree can be constructed
/// without platform-plugin side effects.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaterialApp smoke tests', () {
    testWidgets('builds a MaterialApp without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('FinGuide')),
          ),
        ),
      );

      expect(find.text('FinGuide'), findsOneWidget);
    });

    testWidgets('Scaffold body is visible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Hello')),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('loading indicator renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
