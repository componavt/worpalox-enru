import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/app.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/widgets/word_token.dart';

/// Loads the bundled levels + scene outside the fake-async zone and starts
/// the app. Uses the real Rocket Summer scene asset.
Future<void> _startApp(WidgetTester tester) async {
  final corpus = CorpusService();
  await tester.runAsync(corpus.load);
  await tester.pumpWidget(WorpaloxApp(corpusService: corpus));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('scene flow: context screen, then the first scene puzzle', (
    tester,
  ) async {
    await _startApp(tester);

    await tester.tap(find.text('Story'));
    await tester.pumpAndSettle();

    // Editorial context is shown; its English text must NOT appear as chips.
    expect(find.text('По зимнему городку прокатилась неожиданная волна тепла.'),
        findsOneWidget);
    expect(find.byType(WordToken), findsNothing);

    // Starting the scene goes straight to the first scene puzzle, skipping
    // the Learn Words stage, with the scene title in the app bar.
    await tester.tap(find.text('Начать фразу 1 из 2'));
    await tester.pumpAndSettle();

    expect(find.byType(WordToken), findsWidgets);
    expect(find.textContaining('Ракетное лето'), findsOneWidget);
    // The scene context text does not leak into the puzzle screen.
    expect(
      find.text('По зимнему городку прокатилась неожиданная волна тепла.'),
      findsNothing,
    );
  });
}
