/// TODO: Analytics/event logging service.
///
/// Future work:
/// - Track user sessions, level completion times
/// - Identify problematic levels
/// - A/B test scoring formulas
/// 
/// For MVP: no analytics (offline-first, privacy-focused).
class AnalyticsService {
  void logLevelStart(int levelId) {}

  void logLevelComplete(int levelId, Duration elapsed, int swaps) {}

  void logHintUsed(int levelId) {}

  void logCheckAttempt(int levelId, bool correct) {}
}
