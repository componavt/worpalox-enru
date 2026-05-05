/// Represents the result of a completed puzzle run.
///
/// Separates game score from learning progress to prevent grinding distortion.
class ScoreResult {
  final int gameScoreDelta;
  final int learningProgressDelta;
  final int prelearnScoreDelta;
  final int hintPenalty;
  final int firstCheckBonus;
  final int repeatPenalty;
  final bool solved;

  const ScoreResult({
    required this.gameScoreDelta,
    required this.learningProgressDelta,
    this.prelearnScoreDelta = 0,
    this.hintPenalty = 0,
    this.firstCheckBonus = 0,
    this.repeatPenalty = 0,
    required this.solved,
  });

  int get totalGameScore =>
      gameScoreDelta - hintPenalty + firstCheckBonus - repeatPenalty;

  int get totalLearningProgress => learningProgressDelta + prelearnScoreDelta;

  factory ScoreResult.success({
    required int baseGameScore,
    required int baseLearningProgress,
    int prelearnCorrect = 0,
    int hintsUsed = 0,
    bool firstCheckSolved = false,
    bool isRepeatLevel = false,
  }) {
    int hintPenalty = hintsUsed * 5;
    int firstCheckBonus = firstCheckSolved ? 20 : 0;
    int repeatPenalty = isRepeatLevel ? 10 : 0;
    int prelearnBonus = prelearnCorrect * 10;

    int gameScoreDelta = baseGameScore;
    int learningProgressDelta = baseLearningProgress;

    if (isRepeatLevel) {
      learningProgressDelta = (learningProgressDelta * 0.3).floor();
    }

    return ScoreResult(
      gameScoreDelta: gameScoreDelta,
      learningProgressDelta: learningProgressDelta,
      prelearnScoreDelta: prelearnBonus,
      hintPenalty: hintPenalty,
      firstCheckBonus: firstCheckBonus,
      repeatPenalty: repeatPenalty,
      solved: true,
    );
  }

  factory ScoreResult.failure() {
    return const ScoreResult(
      gameScoreDelta: 0,
      learningProgressDelta: 0,
      solved: false,
    );
  }
}
