import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/models/stats.dart';

void main() {
  group('Stats', () {
    test('initializes with default values', () {
      final stats = Stats();
      expect(stats.totalGameScore, equals(0));
      expect(stats.learningProgress, equals(0));
      expect(stats.totalSolvedRuns, equals(0));
      expect(stats.uniqueSolvedLevelIds, isEmpty);
      expect(stats.recentLevelIds, isEmpty);
    });

    test('addSolvedLevel adds to unique and recent lists', () {
      final stats = Stats();
      stats.addSolvedLevel(1);
      stats.addSolvedLevel(1);
      stats.addSolvedLevel(2);

      expect(stats.uniqueSolvedLevelIds.length, equals(2));
      expect(stats.uniqueSolvedLevelIds, contains(1));
      expect(stats.uniqueSolvedLevelIds, contains(2));
      expect(stats.recentLevelIds, contains(1));
      expect(stats.recentLevelIds, contains(2));
    });

    test('recentLevelIds maintains window of 20', () {
      final stats = Stats();
      for (int i = 0; i < 25; i++) {
        stats.addSolvedLevel(i);
      }

      expect(stats.recentLevelIds.length, lessThanOrEqualTo(22));
    });

    test('hasSolvedLevel returns correct boolean', () {
      final stats = Stats();
      stats.addSolvedLevel(1);

      expect(stats.hasSolvedLevel(1), isTrue);
      expect(stats.hasSolvedLevel(2), isFalse);
    });

    test('incrementDifficultyCount updates performance map', () {
      final stats = Stats();
      stats.incrementDifficultyCount('easy');
      stats.incrementDifficultyCount('easy');
      stats.incrementDifficultyCount('medium');

      expect(stats.difficultyPerformance['easy'], equals(2));
      expect(stats.difficultyPerformance['medium'], equals(1));
      expect(stats.difficultyPerformance['hard'], equals(0));
    });

    test('JSON serialization round-trip', () {
      final original = Stats(
        totalGameScore: 100,
        learningProgress: 50,
        totalSolvedRuns: 5,
        uniqueSolvedLevelIds: [1, 2, 3],
        totalSwaps: 20,
        totalChecks: 10,
        totalHints: 5,
      );

      final json = original.toJson();
      final restored = Stats.fromJson(json);

      expect(restored.totalGameScore, equals(original.totalGameScore));
      expect(restored.learningProgress, equals(original.learningProgress));
      expect(restored.totalSolvedRuns, equals(original.totalSolvedRuns));
      expect(
        restored.uniqueSolvedLevelIds,
        equals(original.uniqueSolvedLevelIds),
      );
    });
  });
}
