import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/services/difficulty_service.dart';
import 'package:worpalox/models/stats.dart';

void main() {
  group('DifficultyService', () {
    final difficultyService = DifficultyService();

    test('returns easy only for new player', () {
      final stats = Stats();
      final allowed = difficultyService.getAllowedDifficultiesForProfile(stats);
      expect(allowed, equals(['easy']));
    });

    test('returns easy and medium for early progress', () {
      final stats = Stats(learningProgress: 50, totalSolvedRuns: 5);
      final allowed = difficultyService.getAllowedDifficultiesForProfile(stats);
      expect(allowed, contains('easy'));
      expect(allowed, contains('medium'));
    });

    test('returns recommended difficulty based on progress', () {
      final stats = Stats();
      final recommended = difficultyService.getRecommendedDifficulty(stats);
      expect(recommended, equals('easy'));
    });

    test('difficulty from token count', () {
      expect(DifficultyService.difficultyFromTokenCount(3), equals('easy'));
      expect(DifficultyService.difficultyFromTokenCount(4), equals('easy'));
      expect(DifficultyService.difficultyFromTokenCount(5), equals('medium'));
      expect(DifficultyService.difficultyFromTokenCount(6), equals('medium'));
      expect(DifficultyService.difficultyFromTokenCount(7), equals('hard'));
    });
  });
}
