import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/app.dart';
import 'package:worpalox/screens/prelearn_screen.dart';
import 'package:worpalox/screens/puzzle_screen.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/widgets/word_token.dart';

/// Loads the bundled levels outside the fake-async zone and starts the app.
Future<void> _startApp(WidgetTester tester) async {
  final corpus = CorpusService();
  await tester.runAsync(corpus.load);
  await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch asks for a name instead of showing an error', (
    tester,
  ) async {
    await _startApp(tester);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to WORPALOX!'), findsOneWidget);
    expect(find.textContaining('No active profile'), findsNothing);

    await tester.tap(find.text("Let's play"));
    await tester.pumpAndSettle();

    expect(find.text(PreLearnScreen.title), findsOneWidget);

    await tester.tap(find.text('Skip to puzzle'));
    await tester.pumpAndSettle();

    expect(find.text(PuzzleScreen.title), findsOneWidget);
    expect(find.byType(WordToken), findsWidgets);

    // Back to the menu: the stats screen is shown again.
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(find.text('Playing as: Player 1'), findsOneWidget);
  });

  testWidgets('tap a word, then tap another place to move it', (tester) async {
    await _startApp(tester);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's play"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip to puzzle'));
    await tester.pumpAndSettle();

    final tokens = find.byType(WordToken);
    await tester.tap(tokens.at(0));
    await tester.pump();
    expect(find.textContaining('Now tap the place'), findsOneWidget);
    await tester.tap(tokens.at(1));
    await tester.pumpAndSettle();
    // A single move may occasionally solve a short sentence.
    final moved = find.textContaining('Moves: 1').evaluate().isNotEmpty;
    final solved = find.text('Solved!').evaluate().isNotEmpty;
    expect(moved || solved, isTrue);
  });

  testWidgets('drag a word onto another place to move it', (tester) async {
    await _startApp(tester);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's play"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip to puzzle'));
    await tester.pumpAndSettle();

    final tokens = find.byType(WordToken);
    final first = tester.widget<WordToken>(tokens.first).word;
    final gesture = await tester.startGesture(tester.getCenter(tokens.first));
    await tester.pump(const Duration(milliseconds: 50));
    final target = tester.getCenter(tokens.last);
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final words = tester
        .widgetList<WordToken>(find.byType(WordToken))
        .map((w) => w.word)
        .toList();
    expect(words.last, first);
  });
}
