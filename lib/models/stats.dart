/// Represents aggregate statistics for a player profile.
///
/// Schema v2:
/// - Separates game score from learning progress
/// - Tracks unique solved levels as a set (serialized as list)
/// - Tracks recent levels to avoid repetition
/// - Tracks difficulty performance buckets
/// - Tracks pre-learning performance
class Stats {
  int totalGameScore;
  int learningProgress;
  int totalSolvedRuns;
  List<int> uniqueSolvedLevelIds;
  List<int> recentLevelIds;
  int totalSwaps;
  int totalChecks;
  int totalHints;
  int prelearnCorrect;
  int prelearnSkipped;
  Map<String, int> problemWords;
  Map<String, int> difficultyPerformance;

  Stats({
    this.totalGameScore = 0,
    this.learningProgress = 0,
    this.totalSolvedRuns = 0,
    List<int>? uniqueSolvedLevelIds,
    List<int>? recentLevelIds,
    this.totalSwaps = 0,
    this.totalChecks = 0,
    this.totalHints = 0,
    this.prelearnCorrect = 0,
    this.prelearnSkipped = 0,
    Map<String, int>? problemWords,
    Map<String, int>? difficultyPerformance,
  }) : uniqueSolvedLevelIds = uniqueSolvedLevelIds ?? [],
       recentLevelIds = recentLevelIds ?? [],
       problemWords = problemWords ?? {},
       difficultyPerformance =
           difficultyPerformance ?? {'easy': 0, 'medium': 0, 'hard': 0};

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalGameScore: json['totalGameScore'] as int? ?? 0,
      learningProgress: json['learningProgress'] as int? ?? 0,
      totalSolvedRuns: json['totalSolvedRuns'] as int? ?? 0,
      uniqueSolvedLevelIds:
          (json['uniqueSolvedLevelIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      recentLevelIds:
          (json['recentLevelIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      totalSwaps: json['totalSwaps'] as int? ?? 0,
      totalChecks: json['totalChecks'] as int? ?? 0,
      totalHints: json['totalHints'] as int? ?? 0,
      prelearnCorrect: json['prelearnCorrect'] as int? ?? 0,
      prelearnSkipped: json['prelearnSkipped'] as int? ?? 0,
      problemWords:
          (json['problemWords'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      difficultyPerformance:
          (json['difficultyPerformance'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {'easy': 0, 'medium': 0, 'hard': 0},
    );
  }

  Map<String, dynamic> toJson() => {
    'totalGameScore': totalGameScore,
    'learningProgress': learningProgress,
    'totalSolvedRuns': totalSolvedRuns,
    'uniqueSolvedLevelIds': uniqueSolvedLevelIds,
    'recentLevelIds': recentLevelIds,
    'totalSwaps': totalSwaps,
    'totalChecks': totalChecks,
    'totalHints': totalHints,
    'prelearnCorrect': prelearnCorrect,
    'prelearnSkipped': prelearnSkipped,
    'problemWords': problemWords,
    'difficultyPerformance': difficultyPerformance,
  };

  bool hasSolvedLevel(int levelId) {
    return uniqueSolvedLevelIds.contains(levelId);
  }

  void addSolvedLevel(int levelId) {
    if (!uniqueSolvedLevelIds.contains(levelId)) {
      uniqueSolvedLevelIds.add(levelId);
    }
    recentLevelIds.add(levelId);
    if (recentLevelIds.length > 20) {
      recentLevelIds.removeAt(0);
    }
  }

  void incrementDifficultyCount(String difficulty) {
    if (difficultyPerformance.containsKey(difficulty)) {
      difficultyPerformance[difficulty] =
          (difficultyPerformance[difficulty] ?? 0) + 1;
    }
  }

  double get averageSwaps =>
      totalSolvedRuns > 0 ? totalSwaps / totalSolvedRuns : 0.0;

  double get averageChecks =>
      totalSolvedRuns > 0 ? totalChecks / totalSolvedRuns : 0.0;

  double get hintUsageRate =>
      totalSolvedRuns > 0 ? totalHints / totalSolvedRuns : 0.0;

  double get prelearnSuccessRate => (prelearnCorrect + prelearnSkipped) > 0
      ? prelearnCorrect / (prelearnCorrect + prelearnSkipped)
      : 0.0;
}
