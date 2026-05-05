import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/services/scoring_service.dart';

void main() {
  group('ScoringService', () {
    final scoringService = ScoringService();

    test('calculates basic score correctly', () {
      final result = scoringService.calculateScore(
        swaps: 5,
        checks: 2,
        hints: 0,
        solved: true,
        firstCheckSolved: false,
        difficulty: 'easy',
        prelearnCorrect: 0,
        isRepeatLevel: false,
      );

      expect(result.solved, isTrue);
      expect(result.gameScoreDelta, equals(5 * 1 + 2 * 2 + 50));
      expect(result.learningProgressDelta, equals(30));
    });

    test('applies perfect bonus for first-check solve', () {
      final result = scoringService.calculateScore(
        swaps: 3,
        checks: 1,
        hints: 0,
        solved: true,
        firstCheckSolved: true,
        difficulty: 'easy',
        prelearnCorrect: 0,
        isRepeatLevel: false,
      );

      expect(result.firstCheckBonus, equals(20));
      expect(result.learningProgressDelta, equals(30 + 10));
    });

    test('applies hint penalty', () {
      final result = scoringService.calculateScore(
        swaps: 5,
        checks: 2,
        hints: 3,
        solved: true,
        firstCheckSolved: false,
        difficulty: 'easy',
        prelearnCorrect: 0,
        isRepeatLevel: false,
      );

      expect(result.hintPenalty, equals(3 * 5));
      expect(result.totalGameScore, equals(5 * 1 + 2 * 2 + 50 - 3 * 5));
    });

    test('score never goes negative', () {
      final result = scoringService.calculateScore(
        swaps: 0,
        checks: 0,
        hints: 100,
        solved: true,
        firstCheckSolved: false,
        difficulty: 'easy',
        prelearnCorrect: 0,
        isRepeatLevel: false,
      );

      expect(result.totalGameScore, lessThanOrEqualTo(0));
    });

    test('unsolved puzzle gives no score', () {
      final result = scoringService.calculateScore(
        swaps: 10,
        checks: 5,
        hints: 1,
        solved: false,
        firstCheckSolved: false,
        difficulty: 'easy',
        prelearnCorrect: 0,
        isRepeatLevel: false,
      );

      expect(result.solved, isFalse);
      expect(result.totalGameScore, equals(0));
      expect(result.totalLearningProgress, equals(0));
    });

    test('pre-learning correct adds to learning progress', () {
      final result = scoringService.calculateScore(
        swaps: 3,
        checks: 1,
        hints: 0,
        solved: true,
        firstCheckSolved: false,
        difficulty: 'easy',
        prelearnCorrect: 2,
        isRepeatLevel: false,
      );

      expect(result.prelearnScoreDelta, equals(2 * 10));
      expect(result.totalLearningProgress, equals(30 + 2 * 10));
    });

    test('repeat level reduces learning progress gain', () {
      final result = scoringService.calculateScore(
        swaps: 3,
        checks: 1,
        hints: 0,
        solved: true,
        firstCheckSolved: false,
        difficulty: 'easy',
        prelearnCorrect: 0,
        isRepeatLevel: true,
      );

      expect(result.repeatPenalty, equals(10));
      expect(result.learningProgressDelta, equals((30 * 0.3).floor()));
    });
  });
}
