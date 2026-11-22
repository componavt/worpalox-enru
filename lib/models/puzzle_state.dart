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

  /// Green-locking mode: chips the player placed correctly become
  /// immovable for the rest of the run; other chips reorder within the
  /// free slots and jump over locked ones.
  bool lockingEnabled = false;
  final Set<int> _lockedSlots = {};
  int? _newlyLockedSlot;

  /// Minimal number of moves needed to solve the initial shuffle.
  late final int minMoves;

  PuzzleState._(this.level, this._correct, this.terminalPunctuation)
    : _current = const [];

  factory PuzzleState({
    required Level level,
    Random? random,
    bool locking = false,
  }) {
    final tokens = tokenize(level.english);
    var terminal = '';
    if (tokens.length > 1 && _terminalMarks.contains(tokens.last)) {
      terminal = tokens.removeLast();
    }
    final state = PuzzleState._(level, tokens, terminal);
    state.lockingEnabled = locking;
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

  /// True when the chip at [index] sits in a locked (green) slot.
  bool isSlotLocked(int index) => _lockedSlots.contains(index);

  /// Display indices of the movable (non-locked) chips, in order.
  List<int> get freeSlots => [
    for (var i = 0; i < _current.length; i++)
      if (!_lockedSlots.contains(i)) i,
  ];

  /// The insertion point for the end drop zone: the last FREE slot (the
  /// terminal mark of the sentence never becomes a lock target).
  int get lastFreeSlot {
    final free = freeSlots;
    return free.isEmpty ? 0 : free.last;
  }

  /// The slot the last player move locked, if any. The screens use it for
  /// the green state and the single placement-sound request.
  int? get newlyLockedSlot => _newlyLockedSlot;
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
    _newlyLockedSlot = null;
    if (lockingEnabled) {
      if (_lockedSlots.contains(from) || _lockedSlots.contains(to)) {
        return -1;
      }
      // Reorder only the free slots; locked chips keep their positions and
      // the moving chip jumps over them.
      final free = [
        for (var i = 0; i < _current.length; i++)
          if (!_lockedSlots.contains(i)) i,
      ];
      final fromRank = free.indexOf(from);
      final toRank = free.indexOf(to);
      final movable = [for (final i in free) _current[i]];
      final movedToken = movable.removeAt(fromRank);
      movable.insert(toRank, movedToken);
      for (var rank = 0; rank < free.length; rank++) {
        _current[free[rank]] = movable[rank];
      }
      _moveCount++;
      if (_current[to].text == _correct[to]) {
        _lockedSlots.add(to);
        _newlyLockedSlot = to;
      }
    } else {
      final token = _current.removeAt(from);
      _current.insert(to, token);
      _moveCount++;
    }

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

  /// A deterministic start order for the Sound Lab test puzzle: [order] is
  /// the initial display arrangement (same words as the level, any order,
  /// duplicates resolved left to right). No shuffling, no pre-earned
  /// placement rewards.
  factory PuzzleState.fixed({
    required Level level,
    required List<String> order,
    bool locking = false,
  }) {
    final tokens = tokenize(level.english);
    var terminal = '';
    if (tokens.length > 1 && _terminalMarks.contains(tokens.last)) {
      terminal = tokens.removeLast();
    }
    final state = PuzzleState._(level, tokens, terminal);
    state.lockingEnabled = locking;
    final correct = state._correct;
    final used = List<bool>.filled(correct.length, false);
    final ids = <int>[];
    for (final word in order) {
      var idx = -1;
      for (var i = 0; i < correct.length; i++) {
        if (!used[i] && correct[i] == word) {
          idx = i;
          break;
        }
      }
      if (idx == -1) {
        throw ArgumentError.value(order, 'order', 'does not match level words');
      }
      used[idx] = true;
      ids.add(idx);
    }
    state._current = [
      for (var i = 0; i < ids.length; i++) PuzzleToken(ids[i], correct[ids[i]]),
    ];
    state.minMoves = minimalMoves(
      state._current.map((t) => t.text).toList(),
      state._correct,
    );
    return state;
  }

  /// Shuffles the words again. Counters are kept so that reshuffling cannot
  /// be used to erase hints or moves.
  void reshuffle([Random? random]) {
    if (_solved) return;
    _current = _shuffled(random ?? Random());
  }

  /// Minimal number of "take one word and put it elsewhere" moves that turn
  /// [current] into [correct]: length minus the longest common subsequence
  /// of the two texts. Keeping an LCS in place and moving every other word
  /// achieves exactly this count, and fewer moves cannot keep more words.
  /// The previous greedy-pairing + LIS approach overcounted duplicates:
  /// A B A B -> B A B A needs one move, not two.
  static int minimalMoves(List<String> current, List<String> correct) {
    if (current.length != correct.length || current.isEmpty) return 0;
    final n = current.length;
    // lcs[i][j] = LCS length of current[0..i) and correct[0..j).
    final lcs = List.generate(n + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= n; j++) {
        lcs[i][j] = current[i - 1] == correct[j - 1]
            ? lcs[i - 1][j - 1] + 1
            : max(lcs[i - 1][j], lcs[i][j - 1]);
      }
    }
    return n - lcs[n][n];
  }

  /// Game tokens of [english] without the terminal punctuation: exactly the
  /// words the player rearranges. Corpus validation uses this to reject
  /// levels with fewer than two distinguishable movable words, where a
  /// shuffle can look solved without being solved.
  static List<String> movableTokens(String english) {
    final tokens = tokenize(english);
    if (tokens.length > 1 && _terminalMarks.contains(tokens.last)) {
      tokens.removeLast();
    }
    return tokens;
  }
}
