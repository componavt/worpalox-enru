/// Aggregate statistics for a player profile.
///
/// Schema v2 (backward-compatible additions):
/// - game score and learning progress are separate
/// - unique solved levels (set serialized as list) and a window of recent
///   levels used to avoid repetition
/// - per-difficulty solve counts
/// - pre-learning answers: correct, wrong, and skipped sessions
class Stats {
  static const recentWindow = 20;

  int totalGameScore;
  int learningProgress;
  int totalSolvedRuns;
  List<int> uniqueSolvedLevelIds;
  List<int> recentLevelIds;
  int totalMoves;
  int totalHints;
  int prelearnCorrect;
  int prelearnWrong;
  int prelearnSkipped;
  Map<String, int> problemWords;
  Map<String, int> difficultyPerformance;

  Stats({
    this.totalGameScore = 0,
    this.learningProgress = 0,
    this.totalSolvedRuns = 0,
    List<int>? uniqueSolvedLevelIds,
    List<int>? recentLevelIds,
    this.totalMoves = 0,
    this.totalHints = 0,
    this.prelearnCorrect = 0,
    this.prelearnWrong = 0,
    this.prelearnSkipped = 0,
    Map<String, int>? problemWords,
    Map<String, int>? difficultyPerformance,
  }) : uniqueSolvedLevelIds = uniqueSolvedLevelIds ?? [],
       recentLevelIds = recentLevelIds ?? [],
       problemWords = problemWords ?? {},
       difficultyPerformance =
           difficultyPerformance ?? {'easy': 0, 'medium': 0, 'hard': 0};

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  static List<int> _intList(Object? v) =>
      v is List ? v.whereType<num>().map((e) => e.toInt()).toList() : <int>[];

  static Map<String, int> _intMap(Object? v) => v is Map
      ? v.map((k, val) => MapEntry(k.toString(), _int(val)))
      : <String, int>{};

  factory Stats.fromJson(Map<String, dynamic> json) {
    final difficulty = _intMap(json['difficultyPerformance']);
    return Stats(
      totalGameScore: _int(json['totalGameScore']),
      learningProgress: _int(json['learningProgress']),
      totalSolvedRuns: _int(json['totalSolvedRuns']),
      uniqueSolvedLevelIds: _intList(json['uniqueSolvedLevelIds']),
      recentLevelIds: _intList(json['recentLevelIds']),
      // "totalSwaps" is the pre-drag-and-drop name of the same counter.
      totalMoves: _int(json['totalMoves'] ?? json['totalSwaps']),
      totalHints: _int(json['totalHints']),
      prelearnCorrect: _int(json['prelearnCorrect']),
      prelearnWrong: _int(json['prelearnWrong']),
      prelearnSkipped: _int(json['prelearnSkipped']),
      problemWords: _intMap(json['problemWords']),
      difficultyPerformance: {'easy': 0, 'medium': 0, 'hard': 0, ...difficulty},
    );
  }

  Map<String, dynamic> toJson() => {
    'totalGameScore': totalGameScore,
    'learningProgress': learningProgress,
    'totalSolvedRuns': totalSolvedRuns,
    'uniqueSolvedLevelIds': uniqueSolvedLevelIds,
    'recentLevelIds': recentLevelIds,
    'totalMoves': totalMoves,
    'totalHints': totalHints,
    'prelearnCorrect': prelearnCorrect,
    'prelearnWrong': prelearnWrong,
    'prelearnSkipped': prelearnSkipped,
    'problemWords': problemWords,
    'difficultyPerformance': difficultyPerformance,
  };

  bool hasSolvedLevel(int levelId) => uniqueSolvedLevelIds.contains(levelId);

  void addSolvedLevel(int levelId) {
    if (!uniqueSolvedLevelIds.contains(levelId)) {
      uniqueSolvedLevelIds.add(levelId);
    }
    recentLevelIds.remove(levelId);
    recentLevelIds.add(levelId);
    while (recentLevelIds.length > recentWindow) {
      recentLevelIds.removeAt(0);
    }
  }

  void incrementDifficultyCount(String difficulty) {
    if (difficultyPerformance.containsKey(difficulty)) {
      difficultyPerformance[difficulty] =
          (difficultyPerformance[difficulty] ?? 0) + 1;
    }
  }

  double get averageMoves =>
      totalSolvedRuns > 0 ? totalMoves / totalSolvedRuns : 0.0;

  double get hintUsageRate =>
      totalSolvedRuns > 0 ? totalHints / totalSolvedRuns : 0.0;

  double get prelearnSuccessRate => (prelearnCorrect + prelearnWrong) > 0
      ? prelearnCorrect / (prelearnCorrect + prelearnWrong)
      : 0.0;
}
