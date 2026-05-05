/// Provides diff-style hints for puzzle.
///
/// Current: position-based diff (correct/wrong)
/// Future: alignment-based smart hints from enru.talp
class HintService {
  List<HintStatus> getHints(List<String> current, List<String> correct) {
    if (current.length != correct.length) {
      return List.filled(current.length, HintStatus.wrong);
    }
    return List.generate(
      current.length,
      (i) => current[i] == correct[i] ? HintStatus.correct : HintStatus.wrong,
    );
  }

  List<bool> getHintBooleans(List<String> current, List<String> correct) {
    final hints = getHints(current, correct);
    return hints.map((h) => h == HintStatus.correct).toList();
  }
}

enum HintStatus { correct, wrong, unknown }
