/// Breakdown of points earned for one completed puzzle run.
///
/// Game score and learning progress are kept separate so that replaying
/// trivial levels cannot inflate learning progress.
class ScoreResult {
  final int placementPoints;
  final int solveBonus;
  final int efficiencyBonus;
  final int hintPenalty;

  final int baseLearning;
  final int noHintLearningBonus;
  final int prelearnLearning;
  final bool isRepeat;
  final bool solved;

  const ScoreResult({
    this.placementPoints = 0,
    this.solveBonus = 0,
    this.efficiencyBonus = 0,
    this.hintPenalty = 0,
    this.baseLearning = 0,
    this.noHintLearningBonus = 0,
    this.prelearnLearning = 0,
    this.isRepeat = false,
    required this.solved,
  });

  /// Game score earned in this run, never negative.
  int get totalGameScore {
    final raw = placementPoints + solveBonus + efficiencyBonus - hintPenalty;
    return raw < 0 ? 0 : raw;
  }

  /// Learning progress earned in this run. Repeated levels give 30%.
  int get totalLearningProgress {
    final raw = baseLearning + noHintLearningBonus + prelearnLearning;
    return isRepeat ? (raw * 0.3).floor() : raw;
  }

  static const failure = ScoreResult(solved: false);
}
