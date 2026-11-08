import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/models/level.dart';
import 'package:worpalox/models/puzzle_state.dart';

Level _level(String english) => Level(
  id: 1,
  english: english,
  russian: 'ru',
  tokenCount: english.split(' ').length,
  difficulty: 'easy',
  commentaryRu: '',
  prelearnPairs: const [],
);

/// Moves tokens into the correct order one by one (at most n moves).
void _solve(PuzzleState p) {
  final correct = p.wordsCorrect;
  for (var target = 0; target < correct.length && !p.solved; target++) {
    if (p.wordsCurrent[target] == correct[target]) continue;
    final from = p.wordsCurrent.indexWhere(
      (w) => w == correct[target],
      target + 1,
    );
    p.moveToken(from, target);
  }
}

void main() {
  group('PuzzleState', () {
    test('terminal punctuation is fixed, not movable', () {
      final p = PuzzleState(level: _level('The cat sat down .'));
      expect(p.wordsCorrect, ['The', 'cat', 'sat', 'down']);
      expect(p.terminalPunctuation, '.');
    });

    test('inner punctuation stays movable', () {
      final p = PuzzleState(level: _level('Oh , yes ...'));
      expect(p.wordsCorrect, ['Oh', ',', 'yes']);
      expect(p.terminalPunctuation, '...');
    });

    test('initial order differs from the answer', () {
      for (var seed = 0; seed < 50; seed++) {
        final p = PuzzleState(level: _level('A B C D E'), random: Random(seed));
        expect(p.wordsCurrent, isNot(equals(p.wordsCorrect)));
        expect(p.solved, isFalse);
      }
    });

    test('moveToken moves a word to any position', () {
      final p = PuzzleState(level: _level('A B C D'), random: Random(1));
      final before = p.wordsCurrent;
      p.moveToken(3, 0);
      expect(p.wordsCurrent.first, before[3]);
      expect(p.wordsCurrent.sublist(1), before.sublist(0, 3));
      expect(p.moveCount, 1);
    });

    test('invalid moves are ignored', () {
      final p = PuzzleState(level: _level('A B C'));
      expect(p.moveToken(0, 0), -1);
      expect(p.moveToken(-1, 1), -1);
      expect(p.moveToken(0, 9), -1);
      expect(p.moveCount, 0);
    });

    test('solves automatically when order is correct', () {
      final p = PuzzleState(level: _level('A B C D E F'), random: Random(3));
      _solve(p);
      expect(p.solved, isTrue);
      expect(p.wordsCurrent, p.wordsCorrect);
      expect(p.moveToken(0, 1), -1, reason: 'no moves after solving');
    });

    test('duplicate words are handled', () {
      final p = PuzzleState(
        level: _level('to be or not to be'),
        random: Random(5),
      );
      _solve(p);
      expect(p.solved, isTrue);
    });

    test(
      'placement rewards cannot be farmed by moving a word back and forth',
      () {
        final p = PuzzleState(level: _level('A B C D E'), random: Random(7));
        _solve(p);
        final rewards = p.placementRewards;
        expect(rewards, lessThanOrEqualTo(5));
        expect(rewards, greaterThan(0));
      },
    );

    test('every hint request is counted; reshuffle keeps counters', () {
      final p = PuzzleState(level: _level('A B C D'), random: Random(2));
      p.useHint();
      p.useHint();
      p.moveToken(0, 1);
      p.reshuffle(Random(9));
      expect(p.hintCount, 2);
      expect(p.moveCount, 1);
    });

    test('minimalMoves equals length minus longest ordered subsequence', () {
      expect(PuzzleState.minimalMoves(['A', 'B', 'C'], ['A', 'B', 'C']), 0);
      expect(PuzzleState.minimalMoves(['C', 'A', 'B'], ['A', 'B', 'C']), 1);
      expect(PuzzleState.minimalMoves(['C', 'B', 'A'], ['A', 'B', 'C']), 2);
      expect(PuzzleState.minimalMoves(['B', 'A', 'B'], ['B', 'B', 'A']), 1);
    });

    test('a solve with minMoves moves is possible', () {
      final p = PuzzleState(level: _level('A B C D E F G'), random: Random(11));
      expect(p.minMoves, greaterThan(0));
      expect(p.minMoves, lessThan(7));
    });
  });
}
