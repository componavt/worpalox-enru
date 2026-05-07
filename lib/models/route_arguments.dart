import 'level.dart';

/// Arguments passed from pre-learning screen to puzzle screen.
class PreLearnResult {
  final Level level;
  final int correctAnswers;
  final int totalQuestions;
  final bool skipped;

  const PreLearnResult({
    required this.level,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.skipped,
  });
}
