import 'level.dart';
import 'story_scene.dart';

/// Arguments passed from the Learn Words stage to the puzzle stage.
class PreLearnResult {
  final Level level;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalQuestions;
  final bool skipped;

  const PreLearnResult({
    required this.level,
    required this.correctAnswers,
    this.wrongAnswers = 0,
    required this.totalQuestions,
    required this.skipped,
  });
}

/// A running scene: the ordered puzzle levels and the current index.
/// Scene context is shown by StoryScreen, never inside the puzzle.
class SceneRun {
  final StoryScene scene;
  final List<Level> levels;
  final int index;

  const SceneRun({
    required this.scene,
    required this.levels,
    required this.index,
  });
}
