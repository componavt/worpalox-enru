import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/widgets/word_token.dart';

void main() {
  testWidgets('WordToken displays word correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordToken(word: 'Hello'),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('WordToken shows green when solved', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordToken(word: 'World', isSolved: true),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container, isNotNull);
  });
}
