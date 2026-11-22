/// One editor-confirmed word correspondence imported from the corpus
/// alignment, expressed on the actual game tokens: [en] is a 0-based index
/// of a movable English chip in its correct order, [ru] is a 0-based index
/// of a word in the Russian clue (punctuation excluded).
class AlignmentLink {
  final int en;
  final int ru;

  const AlignmentLink({required this.en, required this.ru});

  factory AlignmentLink.fromJson(Map<String, dynamic> json) =>
      AlignmentLink(en: json['en'] as int, ru: json['ru'] as int);

  Map<String, dynamic> toJson() => {'en': en, 'ru': ru};
}

/// Editor-approved correspondences for one level. Only confirmed links
/// travel here; the lens reads them, quiz cards are curated separately.
class LevelAlignment {
  final List<AlignmentLink> links;

  const LevelAlignment({required this.links});

  factory LevelAlignment.fromJson(Map<String, dynamic> json) =>
      LevelAlignment(
        links: (json['links'] as List)
            .map((e) => AlignmentLink.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'links': links.map((l) => l.toJson()).toList(),
  };
}

/// Represents a single playable level derived from the corpus.
class Level {
  final int id;
  final String english;
  final String russian;
  final int tokenCount;
  final String difficulty;
  final String commentaryRu;
  final List<PrelearnPair> prelearnPairs;
  final LevelAlignment? alignment;

  /// Story-only levels are addressed by scene routes but never enter the
  /// random Play pool.
  final bool storyOnly;

  const Level({
    required this.id,
    required this.english,
    required this.russian,
    required this.tokenCount,
    required this.difficulty,
    required this.commentaryRu,
    required this.prelearnPairs,
    this.alignment,
    this.storyOnly = false,
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
      // Always derived from the text so that it cannot drift from the data.
      tokenCount: (json['english'] as String)
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .length,
      difficulty: json['difficulty'] as String? ?? 'medium',
      commentaryRu: json['commentaryRu'] as String? ?? '',
      prelearnPairs: prelearnPairs,
      alignment: json['alignment'] == null
          ? null
          : LevelAlignment.fromJson(json['alignment'] as Map<String, dynamic>),
      storyOnly: json['storyOnly'] as bool? ?? false,
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
    'alignment': alignment?.toJson(),
    'storyOnly': storyOnly,
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
