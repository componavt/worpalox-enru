/// Aggregate statistics tracked across all gameplay sessions.
/// 
/// Schema v1:
/// - totalSolved: number of levels completed
/// - totalSwaps: cumulative swap count
/// - totalChecks: cumulative check count
/// - totalHints: cumulative hint usage
/// - levelsCompleted: list of level IDs solved
/// - problemWords: map of word -> occurrence count in mistakes
class Stats {
  int totalSolved;
  int totalSwaps;
  int totalChecks;
  int totalHints;
  List<int> levelsCompleted;
  Map<String, int> problemWords;

  Stats({
    this.totalSolved = 0,
    this.totalSwaps = 0,
    this.totalChecks = 0,
    this.totalHints = 0,
    List<int>? levelsCompleted,
    Map<String, int>? problemWords,
  })  : levelsCompleted = levelsCompleted ?? [],
        problemWords = problemWords ?? {};

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalSolved: json['totalSolved'] as int? ?? 0,
      totalSwaps: json['totalSwaps'] as int? ?? 0,
      totalChecks: json['totalChecks'] as int? ?? 0,
      totalHints: json['totalHints'] as int? ?? 0,
      levelsCompleted: (json['levelsCompleted'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      problemWords: (json['problemWords'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
    'totalSolved': totalSolved,
    'totalSwaps': totalSwaps,
    'totalChecks': totalChecks,
    'totalHints': totalHints,
    'levelsCompleted': levelsCompleted,
    'problemWords': problemWords,
  };

  double get averageSwaps =>
      totalSolved > 0 ? totalSwaps / totalSolved : 0.0;

  double get averageChecks =>
      totalSolved > 0 ? totalChecks / totalSolved : 0.0;

  double get hintUsageRate =>
      totalSolved > 0 ? totalHints / totalSolved : 0.0;
}
