import 'level.dart';

/// Arguments passed from the Learn Words stage to the puzzle stage.
class PreLearnResult {
  final Level level;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalQuestions;
  final bool skipped;

  const PreLearnResult({
    required this.level,
    required this.correctAnswers,
    this.wrongAnswers = 0,
    required this.totalQuestions,
    required this.skipped,
  });
}
