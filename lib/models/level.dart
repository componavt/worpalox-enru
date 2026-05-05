/// Represents a single playable level derived from the corpus.
class Level {
  final int id;
  final String english;
  final String russian;
  final int tokenCount;
  final String? alignment;

  const Level({
    required this.id,
    required this.english,
    required this.russian,
    required this.tokenCount,
    this.alignment,
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as int,
      english: json['english'] as String,
      russian: json['russian'] as String,
      tokenCount: json['tokenCount'] as int,
      alignment: json['alignment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'english': english,
    'russian': russian,
    'tokenCount': tokenCount,
    'alignment': alignment,
  };
}
