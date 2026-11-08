import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/services/scoring_service.dart';

void main() {
  group('ScoringService', () {
    final scoring = ScoringService();

    test(
      'perfect solve: placements + solve + efficiency, bonus counted once',
      () {
        final r = scoring.calculateScore(
          solved: true,
          moves: 3,
          minMoves: 3,
          placements: 4,
          hints: 0,
        );
        expect(r.placementPoints, 8);
        expect(r.solveBonus, 50);
        expect(r.efficiencyBonus, 20);
        expect(r.totalGameScore, 8 + 50 + 20);
        expect(r.totalLearningProgress, 30 + 10);
      },
    );

    test('extra moves never increase the score', () {
      final efficient = scoring.calculateScore(
        solved: true,
        moves: 3,
        minMoves: 3,
        placements: 4,
        hints: 0,
      );
      final wasteful = scoring.calculateScore(
        solved: true,
        moves: 30,
        minMoves: 3,
        placements: 4,
        hints: 0,
      );
      expect(wasteful.totalGameScore, lessThan(efficient.totalGameScore));
    });

    test('good efficiency within twice the minimum', () {
      final r = scoring.calculateScore(
        solved: true,
        moves: 6,
        minMoves: 3,
        placements: 4,
        hints: 0,
      );
      expect(r.efficiencyBonus, 10);
    });

    test('hints cost points and the no-hint learning bonus', () {
      final r = scoring.calculateScore(
        solved: true,
        moves: 9,
        minMoves: 3,
        placements: 2,
        hints: 3,
      );
      expect(r.hintPenalty, 15);
      expect(r.totalGameScore, 4 + 50 - 15);
      expect(r.totalLearningProgress, 30);
    });

    test('game score never goes negative', () {
      final r = scoring.calculateScore(
        solved: true,
        moves: 99,
        minMoves: 3,
        placements: 0,
        hints: 100,
      );
      expect(r.totalGameScore, 0);
    });

    test('unsolved gives nothing', () {
      final r = scoring.calculateScore(
        solved: false,
        moves: 10,
        minMoves: 3,
        placements: 3,
        hints: 1,
      );
      expect(r.solved, isFalse);
      expect(r.totalGameScore, 0);
      expect(r.totalLearningProgress, 0);
    });

    test('pre-learning answers add learning progress', () {
      final r = scoring.calculateScore(
        solved: true,
        moves: 3,
        minMoves: 3,
        placements: 3,
        hints: 0,
        prelearnCorrect: 2,
      );
      expect(r.totalLearningProgress, 30 + 10 + 20);
    });

    test(
      'repeat level gives 30% of all learning progress, including pre-learning',
      () {
        final r = scoring.calculateScore(
          solved: true,
          moves: 3,
          minMoves: 3,
          placements: 3,
          hints: 0,
          prelearnCorrect: 2,
          isRepeatLevel: true,
        );
        expect(r.totalLearningProgress, ((30 + 10 + 20) * 0.3).floor());
      },
    );
  });
}
