/// A curated story scene: editorial context followed by puzzle steps.
///
/// Context steps are editorial summaries (textKind editorial_summary) and
/// never become playable levels; puzzle steps reference existing levels by
/// id. The scene is a route for the player, not a source of random levels.
class StoryScene {
  final String id;
  final String titleRu;
  final List<StoryStep> steps;

  const StoryScene({
    required this.id,
    required this.titleRu,
    required this.steps,
  });

  factory StoryScene.fromJson(Map<String, dynamic> json) => StoryScene(
    id: json['id'] as String,
    titleRu: json['titleRu'] as String,
    steps: (json['steps'] as List)
        .map((e) => StoryStep.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// The puzzle steps in order (sourceLineId is provenance, levelId is the
  /// actual playable level).
  List<StoryStep> get puzzleSteps =>
      steps.where((s) => s.kind == 'puzzle').toList();

  /// The context steps in order.
  List<StoryStep> get contextSteps =>
      steps.where((s) => s.kind == 'context').toList();
}

class StoryStep {
  final String kind; // "context" | "puzzle"
  final List<int> sourceLineIds;
  final String? textRu;
  final String? textKind;
  final int? levelId;

  const StoryStep({
    required this.kind,
    this.sourceLineIds = const [],
    this.textRu,
    this.textKind,
    this.levelId,
  });

  factory StoryStep.fromJson(Map<String, dynamic> json) => StoryStep(
    kind: json['kind'] as String,
    sourceLineIds: (json['sourceLineIds'] as List?)?.cast<int>() ?? const [],
    textRu: json['textRu'] as String?,
    textKind: json['textKind'] as String?,
    levelId: json['levelId'] as int?,
  );
}
