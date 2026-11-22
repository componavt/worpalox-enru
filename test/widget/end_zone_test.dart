import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/app.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/widgets/word_token.dart';

/// Loads the bundled levels outside the fake-async zone and starts the app.
Future<void> _startApp(WidgetTester tester) async {
  final corpus = CorpusService();
  await tester.runAsync(corpus.load);
  await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
  await tester.pumpAndSettle();
}

Future<void> _openPuzzle(WidgetTester tester) async {
  await tester.tap(find.text('Play'));
  await tester.pumpAndSettle();
  await tester.tap(find.text("Let's play"));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Skip to puzzle'));
  await tester.pumpAndSettle();
}

List<String> _words(WidgetTester tester) => tester
    .widgetList<WordToken>(find.byType(WordToken))
    .map((w) => w.word)
    .toList();

String? _movesText(WidgetTester tester) {
  final matches = find.textContaining('Moves:').evaluate();
  if (matches.isEmpty) return null;
  return tester.widget<Text>(find.textContaining('Moves:')).data;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dragging a word onto the end zone puts it last', (tester) async {
    await _startApp(tester);
    await _openPuzzle(tester);

    final before = _words(tester);
    expect(before.length, greaterThan(1));
    // Pick the first word that is not already in the last slot, so the
    // move is observable regardless of the random shuffle.
    var dragIndex = 0;
    while (dragIndex == before.length - 1) {
      dragIndex++;
    }
    final dragged = before[dragIndex];

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WordToken).at(dragIndex)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // The end drop zone is the last DragTarget in the sentence Wrap.
    await gesture.moveTo(tester.getCenter(find.byType(DragTarget<int>).last));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final after = _words(tester);
    expect(after.last, dragged);
    expect(after.length, before.length);
  });

  testWidgets('dropping the already-last word onto the end zone is a no-op', (
    tester,
  ) async {
    await _startApp(tester);
    await _openPuzzle(tester);

    final before = _words(tester);
    final movesBefore = _movesText(tester);
    expect(movesBefore, isNotNull);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(WordToken).at(before.length - 1)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byType(DragTarget<int>).last));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // No phantom move: the order and the move counter did not change.
    expect(_words(tester), before);
    expect(_movesText(tester), movesBefore);
    expect(find.text('Solved!'), findsNothing);
  });
}
