import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/services/scoring_service.dart';

void main() {
  group('ScoringService', () {
    final scoringService = ScoringService();

    test('calculates basic score correctly', () {
      final score = scoringService.calculateScore(
        swaps: 5,
        checks: 2,
        hints: 0,
        solved: true,
        firstCheckSolved: false,
      );
      
      expect(score, equals(5 * 1 + 2 * 2 + 50)); 
    });

    test('applies perfect bonus for first-check solve', () {
      final score = scoringService.calculateScore(
        swaps: 3,
        checks: 1,
        hints: 0,
        solved: true,
        firstCheckSolved: true,
      );
      
      expect(score, equals(3 * 1 + 1 * 2 + 50 + 20)); 
    });

    test('applies hint penalty', () {
      final score = scoringService.calculateScore(
        swaps: 5,
        checks: 2,
        hints: 3,
        solved: true,
        firstCheckSolved: false,
      );
      
      expect(score, equals(5 * 1 + 2 * 2 + 50 - 3 * 5)); 
    });

    test('score never goes negative', () {
      final score = scoringService.calculateScore(
        swaps: 0,
        checks: 0,
        hints: 100,
        solved: false,
        firstCheckSolved: false,
      );
      
      expect(score, equals(0)); 
    });

    test('unsolved puzzle gives no solve bonus', () {
      final score = scoringService.calculateScore(
        swaps: 10,
        checks: 5,
        hints: 1,
        solved: false,
        firstCheckSolved: false,
      );
      
      expect(score, equals(10 * 1 + 5 * 2 - 1 * 5)); 
    });
  });
}
