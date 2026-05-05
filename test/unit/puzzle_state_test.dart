import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/models/puzzle_state.dart';
import 'package:worpalox/models/level.dart';

void main() {
  group('PuzzleState', () {
    test('tokenizes sentence correctly', () {
      final level = Level(
        id: 1,
        english: 'The cat sat down .',
        russian: 'Кошка села .',
        tokenCount: 4,
        difficulty: 'easy',
        commentaryRu: 'Test',
        prelearnPairs: [],
      );
      final puzzle = PuzzleState(level: level);
      expect(puzzle.wordsCorrect, equals(['The', 'cat', 'sat', 'down', '.']));
    });

    test('swapAdjacent swaps words correctly', () {
      final level = Level(
        id: 1,
        english: 'A B C',
        russian: 'X Y Z',
        tokenCount: 3,
        difficulty: 'easy',
        commentaryRu: 'Test',
        prelearnPairs: [],
      );
      final puzzle = PuzzleState(level: level);
      final initial = puzzle.wordsCurrent.toList();

      final result = puzzle.swapAdjacent(0);

      expect(result, isTrue);
      expect(puzzle.swapCount, equals(1));
      expect(puzzle.wordsCurrent[0], equals(initial[1]));
      expect(puzzle.wordsCurrent[1], equals(initial[0]));
    });

    test('swapAdjacent returns false for invalid index', () {
      final level = Level(
        id: 1,
        english: 'A B C',
        russian: 'X Y Z',
        tokenCount: 3,
        difficulty: 'easy',
        commentaryRu: 'Test',
        prelearnPairs: [],
      );
      final puzzle = PuzzleState(level: level);

      expect(puzzle.swapAdjacent(-1), isFalse);
      expect(puzzle.swapAdjacent(10), isFalse);
    });

    test('check increments checkCount', () {
      final level = Level(
        id: 1,
        english: 'Hello world',
        russian: 'Привет мир',
        tokenCount: 2,
        difficulty: 'easy',
        commentaryRu: 'Test',
        prelearnPairs: [],
      );
      final puzzle = PuzzleState(level: level);

      puzzle.check();

      expect(puzzle.checkCount, equals(1));
    });

    test('shuffle produces different order', () {
      final level = Level(
        id: 1,
        english: 'A B C D E',
        russian: 'X Y Z W V',
        tokenCount: 5,
        difficulty: 'easy',
        commentaryRu: 'Test',
        prelearnPairs: [],
      );
      final puzzle = PuzzleState(level: level);

      expect(puzzle.wordsCurrent, isNot(equals(puzzle.wordsCorrect)));
    });
  });
}
