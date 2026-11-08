import 'dart:math';

import 'level.dart';

/// A single movable word chip. [id] is unique within a puzzle so that
/// duplicate words (for example two commas) can still be dragged reliably.
class PuzzleToken {
  final int id;
  final String text;

  const PuzzleToken(this.id, this.text);
}

/// Runtime state of one sentence puzzle.
///
/// The player moves any word to any position ([moveToken]). The puzzle is
/// solved automatically as soon as the order matches the original sentence;
/// there is no separate "check" step.
///
/// Terminal punctuation ("." "!" "?" "...") is not a movable token: it is
/// always shown at the end of the sentence via [terminalPunctuation].
class PuzzleState {
  static const _terminalMarks = {'.', '!', '?', '...', '…', '?!', '!?'};

  final Level level;
  final List<String> _correct;
  final String terminalPunctuation;
  List<PuzzleToken> _current;

  int _moveCount = 0;
  int _hintCount = 0;
  bool _solved = false;
  final DateTime _startTime = DateTime.now();
  DateTime? _solveTime;

  /// Positions that have already earned a placement reward in this run.
  final Set<int> _rewardedPositions = {};
  int _placementRewards = 0;

  /// Minimal number of moves needed to solve the initial shuffle.
  late final int minMoves;

  PuzzleState._(this.level, this._correct, this.terminalPunctuation)
    : _current = const [];

  factory PuzzleState({required Level level, Random? random}) {
    final tokens = tokenize(level.english);
    var terminal = '';
    if (tokens.length > 1 && _terminalMarks.contains(tokens.last)) {
      terminal = tokens.removeLast();
    }
    final state = PuzzleState._(level, tokens, terminal);
    state._current = state._shuffled(random ?? Random());
    state.minMoves = minimalMoves(
      state._current.map((t) => t.text).toList(),
      state._correct,
    );
    // Words that already sit in the right place after the shuffle do not
    // earn placement rewards later.
    for (var i = 0; i < state._correct.length; i++) {
      if (state._current[i].text == state._correct[i]) {
        state._rewardedPositions.add(i);
      }
    }
    return state;
  }

  /// Splits a sentence on whitespace. The corpus already separates
  /// punctuation with spaces.
  static List<String> tokenize(String text) =>
      text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  List<PuzzleToken> _shuffled(Random random) {
    final base = [
      for (var i = 0; i < _correct.length; i++) PuzzleToken(i, _correct[i]),
    ];
    if (_correct.toSet().length < 2) return base;
    var result = base.toList();
    for (var attempt = 0; attempt < 100; attempt++) {
      result = base.toList()..shuffle(random);
      if (!_matches(result)) break;
    }
    return result;
  }

  bool _matches(List<PuzzleToken> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].text != _correct[i]) return false;
    }
    return true;
  }

  List<PuzzleToken> get tokens => List.unmodifiable(_current);
  List<String> get wordsCurrent => _current.map((t) => t.text).toList();
  List<String> get wordsCorrect => List.unmodifiable(_correct);
  int get moveCount => _moveCount;
  int get hintCount => _hintCount;
  int get placementRewards => _placementRewards;
  bool get solved => _solved;
  Duration get elapsed => (_solveTime ?? DateTime.now()).difference(_startTime);

  bool isPositionCorrect(int index) => _current[index].text == _correct[index];

  /// Moves the token at [from] so that it ends up at index [to].
  ///
  /// Returns the number of positions that became correct for the first time
  /// in this run (each worth a small reward), or -1 if the move was ignored.
  int moveToken(int from, int to) {
    if (_solved ||
        from == to ||
        from < 0 ||
        to < 0 ||
        from >= _current.length ||
        to >= _current.length) {
      return -1;
    }
    final token = _current.removeAt(from);
    _current.insert(to, token);
    _moveCount++;

    var newlyCorrect = 0;
    for (var i = 0; i < _current.length; i++) {
      if (isPositionCorrect(i) && _rewardedPositions.add(i)) {
        newlyCorrect++;
      }
    }
    _placementRewards += newlyCorrect;

    if (_matches(_current)) {
      _solved = true;
      _solveTime = DateTime.now();
    }
    return newlyCorrect;
  }

  /// Registers one hint use. Every request is counted.
  void useHint() {
    if (!_solved) _hintCount++;
  }

  /// Shuffles the words again. Counters are kept so that reshuffling cannot
  /// be used to erase hints or moves.
  void reshuffle([Random? random]) {
    if (_solved) return;
    _current = _shuffled(random ?? Random());
  }

  /// Minimal number of "take one word and put it elsewhere" moves that turn
  /// [current] into [correct]: length minus the longest subsequence that is
  /// already in the right relative order.
  static int minimalMoves(List<String> current, List<String> correct) {
    if (current.length != correct.length || current.isEmpty) return 0;
    // Map each current word to a target index; duplicates are assigned in
    // order of appearance, which is optimal for equal words.
    final used = List<bool>.filled(correct.length, false);
    final targets = <int>[];
    for (final word in current) {
      var idx = -1;
      for (var j = 0; j < correct.length; j++) {
        if (!used[j] && correct[j] == word) {
          idx = j;
          break;
        }
      }
      if (idx == -1) return current.length;
      used[idx] = true;
      targets.add(idx);
    }
    // Longest increasing subsequence (patience sorting).
    final tails = <int>[];
    for (final t in targets) {
      var lo = 0, hi = tails.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (tails[mid] < t) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo == tails.length) {
        tails.add(t);
      } else {
        tails[lo] = t;
      }
    }
    return current.length - tails.length;
  }
}
