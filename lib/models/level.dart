/// Represents a single playable level derived from the corpus.
class Level {
  final int id;
  final String english;
  final String russian;
  final int tokenCount;
  final String difficulty;
  final String commentaryRu;
  final List<PrelearnPair> prelearnPairs;
  final String? alignment;

  const Level({
    required this.id,
    required this.english,
    required this.russian,
    required this.tokenCount,
    required this.difficulty,
    required this.commentaryRu,
    required this.prelearnPairs,
    this.alignment,
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    List<PrelearnPair> prelearnPairs = [];
    if (json['prelearnPairs'] != null) {
      prelearnPairs = (json['prelearnPairs'] as List)
          .map((e) => PrelearnPair.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Level(
      id: json['id'] as int,
      english: json['english'] as String,
      russian: json['russian'] as String,
      tokenCount: json['tokenCount'] as int,
      difficulty: json['difficulty'] as String? ?? 'medium',
      commentaryRu: json['commentaryRu'] as String? ?? '',
      prelearnPairs: prelearnPairs,
      alignment: json['alignment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'english': english,
    'russian': russian,
    'tokenCount': tokenCount,
    'difficulty': difficulty,
    'commentaryRu': commentaryRu,
    'prelearnPairs': prelearnPairs.map((p) => p.toJson()).toList(),
    'alignment': alignment,
  };
}

/// Represents a curated English-Russian word pair for pre-learning.
class PrelearnPair {
  final String en;
  final String ru;

  const PrelearnPair({required this.en, required this.ru});

  factory PrelearnPair.fromJson(Map<String, dynamic> json) {
    return PrelearnPair(en: json['en'] as String, ru: json['ru'] as String);
  }

  Map<String, dynamic> toJson() => {'en': en, 'ru': ru};
}
