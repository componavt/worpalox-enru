import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/app.dart';
import 'package:worpalox/models/level.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/services/session_block.dart';
import 'package:worpalox/widgets/block_progress.dart';

Level _level(int id) => Level(
  id: id,
  english: 'the doors flew open .',
  russian: 'ru',
  tokenCount: 5,
  difficulty: 'easy',
  commentaryRu: '',
  prelearnPairs: const [],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Play from the menu starts a fresh block', (tester) async {
    // A block left over from a previous session (or another profile) must
    // not leak into a new game started from the menu.
    final block = SessionBlock()
      ..registerSolved()
      ..registerSolved();
    final corpus = CorpusService()..setLevels([_level(1), _level(2)]);
    await tester.pumpWidget(
      WorpaloxApp(corpusService: corpus, sessionBlock: block),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's play"));
    await tester.pumpAndSettle();
    // Empty prelearn pairs auto-skip straight to the puzzle.
    expect(find.byType(BlockProgress), findsOneWidget);

    final bar = tester.widget<BlockProgress>(find.byType(BlockProgress));
    expect(bar.solved, 0);
    expect(bar.total, SessionBlock.blockSize);
  });
}
