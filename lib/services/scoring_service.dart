/// Scoring formula (transparent, motivating):
/// - Each valid swap: +1 point (encourages interaction)
/// - Each check (even wrong): +2 points (encourages engagement)
/// - Solve bonus: +50 points
/// - First-check solve (no hints): +20 bonus
/// - Hint used: -5 points per hint (minor penalty, not punishing)
class ScoringService {
  static const swapPoints = 1;
  static const checkPoints = 2;
  static const solveBonus = 50;
  static const perfectBonus = 20;
  static const hintPenalty = 5;

  int calculateScore({
    required int swaps,
    required int checks,
    required int hints,
    required bool solved,
    required bool firstCheckSolved,
  }) {
    int score = 0;
    score += swaps * swapPoints;
    score += checks * checkPoints;
    if (solved) {
      score += solveBonus;
      if (firstCheckSolved) score += perfectBonus;
    }
    score -= hints * hintPenalty;
    return score.clamp(0, 9999);
  }
}
