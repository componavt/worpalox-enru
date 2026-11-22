import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/app.dart';
import 'package:worpalox/models/level.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/widgets/word_token.dart';

Level _level(
  int id,
  String english,
  String russian, {
  List<Map<String, int>>? links,
}) => Level(
  id: id,
  english: english,
  russian: russian,
  tokenCount: english.split(' ').length,
  difficulty: 'easy',
  commentaryRu: '',
  prelearnPairs: const [],
  alignment: links == null
      ? null
      : LevelAlignment(
          links: links
              .map((l) => AlignmentLink(en: l['en']!, ru: l['ru']!))
              .toList(),
        ),
);

Future<void> _openPuzzle(WidgetTester tester) async {
  await tester.tap(find.text('Play'));
  await tester.pumpAndSettle();
  await tester.tap(find.text("Let's play"));
  await tester.pumpAndSettle();
  // Empty prelearnPairs auto-skip straight to the puzzle.
  final skip = find.text('Skip to puzzle');
  if (skip.evaluate().isNotEmpty) {
    await tester.tap(skip);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lens highlights the linked chip when a clue word is tapped', (
    tester,
  ) async {
    final corpus = CorpusService()
      ..setLevels([
        _level(101, 'The doors flew open .', 'Двери распахнулись .', links: [
          {'en': 1, 'ru': 0}, // doors <-> Двери
          {'en': 2, 'ru': 1}, // flew <-> распахнулись
          {'en': 3, 'ru': 1}, // open <-> распахнулись
        ]),
      ]);
    await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
    await tester.pumpAndSettle();
    await _openPuzzle(tester);

    // Tap the Russian clue word Двери: only the doors chip turns amber
    // (translated is an independent channel, the state stays positional).
    await tester.tap(find.text('Двери'));
    await tester.pump();
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'doors'))
          .translated,
      isTrue,
    );
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'the'))
          .translated,
      isFalse,
    );
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'flew'))
          .translated,
      isFalse,
    );

    // Tap распахнулись: both chips of the many-to-one group light up.
    await tester.tap(find.text('распахнулись'));
    await tester.pump();
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'doors'))
          .translated,
      isFalse,
    );
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

    // A move (tap-tap: select a chip, then tap the place for it) closes
    // the lens: no chip stays amber afterwards.
    await tester.tap(find.byType(WordToken).first);
    await tester.pump();
    await tester.tap(find.byType(WordToken).at(1));
    await tester.pumpAndSettle();
    final translated = tester
        .widgetList<WordToken>(find.byType(WordToken))
        .map((w) => w.translated);
    expect(translated, everyElement(isFalse));
  });

  testWidgets('apostrophe-folded alignment lights the merged chip', (
    tester,
  ) async {
    // Corpus "Jane ' s" is curated as one chip "Jane's": the lens data was
    // remapped by the importer, so tapping Джейн lights that chip.
    final corpus = CorpusService()
      ..setLevels([
        _level(120, "Jane's lips twisted slightly .", 'Губы Джейн слегка искривились .',
            links: [
              {'en': 1, 'ru': 0}, // lips <-> Губы
              {'en': 0, 'ru': 1}, // Jane's <-> Джейн
              {'en': 3, 'ru': 2}, // slightly <-> слегка
              {'en': 2, 'ru': 3}, // twisted <-> искривились
            ]),
      ]);
    await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
    await tester.pumpAndSettle();
    await _openPuzzle(tester);

    await tester.tap(find.text('Джейн'));
    await tester.pump();
    expect(
      tester.widget<WordToken>(
        find.widgetWithText(WordToken, "Jane's"),
      ).translated,
      isTrue,
    );
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'lips'))
          .translated,
      isFalse,
    );
  });

  testWidgets('a level without alignment has no lens taps', (tester) async {
    final corpus = CorpusService()
      ..setLevels([
        _level(150, 'The doors flew open .', 'Двери распахнулись .'),
      ]);
    await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
    await tester.pumpAndSettle();
    await _openPuzzle(tester);

    await tester.tap(find.text('Двери'));
    await tester.pump();
    expect(
      tester.widget<WordToken>(find.widgetWithText(WordToken, 'doors')).state,
      WordTokenState.normal,
    );
  });
}
