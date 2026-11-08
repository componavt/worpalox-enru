import '../models/score_result.dart';

/// Scoring formula (transparent, rewards every useful action):
///
/// Game score:
/// - Word lands on its correct place for the first time: +2 per word
/// - Solve bonus: +50
/// - Efficiency: +20 if solved in the minimal number of moves,
///   +10 if within twice the minimum
/// - Each hint: -5
/// - The total for a run is never negative
///
/// Learning progress:
/// - Base: +30 for solving
/// - No hints used: +10
/// - Pre-learning: +10 per correct answer
/// - Repeated level: 30% of the above (anti-grinding)
class ScoringService {
  static const placementPoints = 2;
  static const solveBonus = 50;
  static const perfectEfficiencyBonus = 20;
  static const goodEfficiencyBonus = 10;
  static const hintPenalty = 5;
  static const baseLearningProgress = 30;
  static const noHintLearningBonus = 10;
  static const prelearnPoints = 10;

  ScoreResult calculateScore({
    required bool solved,
    required int moves,
    required int minMoves,
    required int placements,
    required int hints,
    int prelearnCorrect = 0,
    bool isRepeatLevel = false,
  }) {
    if (!solved) return ScoreResult.failure;

    var efficiency = 0;
    if (moves <= minMoves) {
      efficiency = perfectEfficiencyBonus;
    } else if (moves <= minMoves * 2) {
      efficiency = goodEfficiencyBonus;
    }

    return ScoreResult(
      placementPoints: placements * placementPoints,
      solveBonus: solveBonus,
      efficiencyBonus: efficiency,
      hintPenalty: hints * hintPenalty,
      baseLearning: baseLearningProgress,
      noHintLearningBonus: hints == 0 ? noHintLearningBonus : 0,
      prelearnLearning: prelearnCorrect * prelearnPoints,
      isRepeat: isRepeatLevel,
      solved: true,
    );
  }
}
