import '../models/score_result.dart';

/// Scoring formula (transparent, motivating):
///
/// Game Score:
/// - Each valid swap: +1 point
/// - Each check (even wrong): +2 points
/// - Solve bonus: +50 points
/// - First-check solve: +20 bonus
/// - Hint used: -5 points per hint
///
/// Learning Progress:
/// - Base progress: +30 points for solving
/// - First-check solve: +10 bonus
/// - Pre-learning correct: +10 per correct answer
/// - Repeated easy level: 30% progress gain (anti-grinding)
class ScoringService {
  static const swapPoints = 1;
  static const checkPoints = 2;
  static const solveBonus = 50;
  static const perfectBonus = 20;
  static const hintPenalty = 5;
  static const baseLearningProgress = 30;
  static const perfectLearningBonus = 10;
  static const prelearnPoints = 10;

  ScoreResult calculateScore({
    required int swaps,
    required int checks,
    required int hints,
    required bool solved,
    required bool firstCheckSolved,
    required String difficulty,
    int prelearnCorrect = 0,
    bool isRepeatLevel = false,
  }) {
    if (!solved) {
      return ScoreResult.failure();
    }

    int gameScoreDelta = 0;
    int learningProgressDelta = baseLearningProgress;

    gameScoreDelta += swaps * swapPoints;
    gameScoreDelta += checks * checkPoints;
    gameScoreDelta += solveBonus;

    if (firstCheckSolved) {
      gameScoreDelta += perfectBonus;
      learningProgressDelta += perfectLearningBonus;
    }

    int hintPenaltyTotal = hints * hintPenalty;
    int firstCheckBonus = firstCheckSolved ? perfectBonus : 0;
    int repeatPenalty = 0;

    if (isRepeatLevel) {
      learningProgressDelta = (learningProgressDelta * 0.3).floor();
      repeatPenalty = 10;
    }

    int prelearnScoreDelta = prelearnCorrect * prelearnPoints;

    return ScoreResult(
      gameScoreDelta: gameScoreDelta,
      learningProgressDelta: learningProgressDelta,
      prelearnScoreDelta: prelearnScoreDelta,
      hintPenalty: hintPenaltyTotal,
      firstCheckBonus: firstCheckBonus,
      repeatPenalty: repeatPenalty,
      solved: true,
    );
  }

  ScoreResult calculatePrelearnScore({
    required int correctAnswers,
    required int totalQuestions,
    bool skipped = false,
  }) {
    if (skipped) {
      return const ScoreResult(
        gameScoreDelta: 0,
        learningProgressDelta: 0,
        prelearnScoreDelta: 0,
        solved: false,
      );
    }

    int prelearnScoreDelta = correctAnswers * prelearnPoints;

    return ScoreResult(
      gameScoreDelta: 0,
      learningProgressDelta: 0,
      prelearnScoreDelta: prelearnScoreDelta,
      solved: true,
    );
  }
}
