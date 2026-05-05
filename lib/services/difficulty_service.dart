/// TODO: Difficulty classifier service.
///
/// Future work:
/// - Analyze sentence complexity (vocab rarity, grammar structures)
/// - Track player performance per difficulty tier
/// - Recommend appropriate levels
/// 
/// For MVP: returns default difficulty.
class DifficultyService {
  DifficultyLevel classifyLevel(String english, String russian) {
    return DifficultyLevel.medium;
  }
}

enum DifficultyLevel { easy, medium, hard }
