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

void _solve(PuzzleState p) {
  final correct = p.wordsCorrect;
  for (var target = 0; target < correct.length && !p.solved; target++) {
    if (p.wordsCurrent[target] == correct[target]) continue;
    final from = p.wordsCurrent.indexWhere(
      (w) => w == correct[target],
      target + 1,
    );
    if (from == -1) continue;
    p.moveToken(from, target);
  }
}

void main() {
  test('locking mode stays solvable through insertion-sort moves', () {
    final p = PuzzleState(
      level: _level('The icicles dropped , shattering , to melt .'),
      random: Random(7),
      locking: true,
    );
    expect(p.lockingEnabled, isTrue);
    _solve(p);
    expect(p.solved, isTrue, reason: 'words: ${p.wordsCurrent}');
  });

  test('shuffle keeps locked chips and stays solvable', () {
    final p = PuzzleState(
      level: _level('The icicles dropped , shattering , to melt .'),
      random: Random(3),
      locking: true,
    );
    // Place the first four words: they lock green and immovable.
    final correct = p.wordsCorrect;
    for (var target = 0; target < 4; target++) {
      if (p.wordsCurrent[target] == correct[target]) continue;
      final from = p.wordsCurrent.indexWhere(
        (w) => w == correct[target],
        target + 1,
      );
      if (from == -1) continue;
      p.moveToken(from, target);
    }
    final lockedSnapshot = [
      for (var i = 0; i < p.tokens.length; i++)
        if (p.isSlotLocked(i)) (i, p.tokens[i].text),
    ];
    expect(lockedSnapshot, isNotEmpty);

    for (var i = 0; i < 10; i++) {
      p.reshuffle(Random(i));
      for (final (slot, text) in lockedSnapshot) {
        expect(p.tokens[slot].text, text,
            reason: 'locked slot $slot changed after shuffle $i');
      }
      expect(p.newlyLockedSlot, isNull,
          reason: 'shuffle must clear the lock event');
    }

    // The remaining free chips can still complete the sentence.
    _solve(p);
    expect(p.solved, isTrue);
  });
}
