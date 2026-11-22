import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/app.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/widgets/block_progress.dart';
import 'package:worpalox/widgets/word_token.dart';

/// Loads the bundled levels + scene outside the fake-async zone.
Future<void> _startApp(WidgetTester tester) async {
  final corpus = CorpusService();
  await tester.runAsync(corpus.load);
  await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
  await tester.pumpAndSettle();
}

/// Solves the current puzzle by tap-tap moves into the correct order.
Future<void> _solveCurrentPuzzle(
  WidgetTester tester,
  List<String> correct,
) async {
  for (var attempt = 0; attempt < correct.length * 2; attempt++) {
    if (find.text('Solved!').evaluate().isNotEmpty) return;
    final current = tester
        .widgetList<WordToken>(find.byType(WordToken))
        .map((w) => w.word)
        .toList();
    var moved = false;
    for (var target = 0; target < correct.length && !moved; target++) {
      if (current[target] == correct[target]) continue;
      final from = current.indexWhere((w) => w == correct[target], target);
      if (from == -1) continue;
      await tester.tap(find.byType(WordToken).at(from));
      await tester.pump();
      await tester.tap(find.byType(WordToken).at(target));
      await tester.pumpAndSettle();
      moved = true;
    }
    if (!moved) break;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('full scene route: context, two puzzles, lens, finale', (
    tester,
  ) async {
    await _startApp(tester);

    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();
    expect(find.text('Начать фразу 1 из 2'), findsOneWidget);
    await tester.tap(find.text('Начать фразу 1 из 2'));
    await tester.pumpAndSettle();

    // Phrase 1 (level 140): solve with tap-tap moves, then continue.
    await _solveCurrentPuzzle(tester,
        ['The', 'icicles', 'dropped', ',', 'shattering', ',', 'to', 'melt']);
    expect(find.text('Solved!'), findsOneWidget);
    await tester.tap(find.text('Next phrase'));
    await tester.pumpAndSettle();

    // Phrase 2 (level 101): the lens is available — tap распахнулись and
    // both linked chips turn amber.
    await tester.tap(find.text('распахнулись'));
    await tester.pump();
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'flew'))
          .translated,
      isTrue,
    );
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'open'))
          .translated,
      isTrue,
    );

    await _solveCurrentPuzzle(tester, ['The', 'doors', 'flew', 'open']);
    expect(find.text('Solved!'), findsOneWidget);
    await tester.tap(find.text('Finish scene'));
    await tester.pumpAndSettle();

    expect(find.text('Scene complete!'), findsOneWidget);
    await tester.tap(find.text('Back to menu'));
    await tester.pumpAndSettle();

    // Scene phrases never fill the Play-mode block: a fresh Play starts
    // from 0/5.
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's play"));
    await tester.pumpAndSettle();
    final bar = tester.widget<BlockProgress>(find.byType(BlockProgress));
    expect(bar.solved, 0);
    expect(bar.total, 5);
  });
}
