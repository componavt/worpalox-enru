import '../models/stats.dart';

/// Difficulty classifier service for adaptive level selection.
class DifficultyService {
  static const List<String> allDifficulties = ['easy', 'medium', 'hard'];

  List<String> getAllowedDifficultiesForProfile(Stats stats) {
    final progress = stats.learningProgress;
    final totalSolved = stats.totalSolvedRuns;

    if (totalSolved < 3) {
      return ['easy'];
    }

    if (progress < 100) {
      return ['easy', 'medium'];
    }

    final mediumCount = stats.difficultyPerformance['medium'] ?? 0;

    if (progress < 300 || mediumCount < 5) {
      return ['easy', 'medium'];
    }

    final hardCount = stats.difficultyPerformance['hard'] ?? 0;
    if (hardCount < 3) {
      return ['medium', 'hard'];
    }

    return ['easy', 'medium', 'hard'];
  }

  String getRecommendedDifficulty(Stats stats) {
    final allowed = getAllowedDifficultiesForProfile(stats);

    if (allowed.length == 1) {
      return allowed.first;
    }

    final mediumCount = stats.difficultyPerformance['medium'] ?? 0;
    final hardCount = stats.difficultyPerformance['hard'] ?? 0;

    if (allowed.contains('medium') &&
        mediumCount <= (stats.difficultyPerformance['easy'] ?? 0)) {
      return 'medium';
    }

    if (allowed.contains('hard') && hardCount <= mediumCount) {
      return 'hard';
    }

    return allowed.contains('medium') ? 'medium' : allowed.first;
  }

  static String difficultyFromTokenCount(int tokenCount) {
    if (tokenCount <= 4) {
      return 'easy';
    } else if (tokenCount <= 6) {
      return 'medium';
    } else {
      return 'hard';
    }
  }
}
