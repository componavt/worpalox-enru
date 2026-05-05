import 'dart:math';
import 'package:flutter/foundation.dart';
import 'level.dart';

class PuzzleState extends ChangeNotifier {
  final Level level;
  final List<String> _wordsCorrect;
  List<String> _wordsCurrent;
  int _swapCount;
  int _checkCount;
  int _hintCount;
  bool _solved;
  final DateTime _startTime;
  DateTime? _solveTime;
  int _hintRequests;

  PuzzleState({required this.level})
    : _wordsCorrect = _tokenize(level.english),
      _wordsCurrent = _tokenize(level.english),
      _swapCount = 0,
      _checkCount = 0,
      _hintCount = 0,
      _solved = false,
      _startTime = DateTime.now(),
      _hintRequests = 0 {
    _shuffle();
  }

  static List<String> _tokenize(String text) {
    final tokens = <String>[];
    var current = '';
    for (final char in text.runes) {
      final ch = String.fromCharCode(char);
      if (ch == ' ') {
        if (current.isNotEmpty) {
          tokens.add(current);
          current = '';
        }
      } else {
        current += ch;
      }
    }
    if (current.isNotEmpty) tokens.add(current);
    return tokens;
  }

  void _shuffle() {
    final random = Random();
    var attempts = 0;
    do {
      _wordsCurrent = _wordsCorrect.toList()..shuffle(random);
      attempts++;
    } while (_listEquals(_wordsCurrent, _wordsCorrect) && attempts < 100);
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<String> get wordsCurrent => _wordsCurrent;
  List<String> get wordsCorrect => _wordsCorrect;
  int get swapCount => _swapCount;
  int get checkCount => _checkCount;
  int get hintCount => _hintCount;
  int get hintRequests => _hintRequests;
  bool get solved => _solved;
  Duration get elapsed => (_solveTime ?? DateTime.now()).difference(_startTime);

  bool swapAdjacent(int index) {
    if (_solved || index < 0 || index >= _wordsCurrent.length - 1) return false;
    final temp = _wordsCurrent[index];
    _wordsCurrent[index] = _wordsCurrent[index + 1];
    _wordsCurrent[index + 1] = temp;
    _swapCount++;
    notifyListeners();
    return true;
  }

  bool check() {
    if (_solved) return false;
    _checkCount++;
    if (_listEquals(_wordsCurrent, _wordsCorrect)) {
      _solved = true;
      _solveTime = DateTime.now();
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  void useHint() {
    _hintRequests++;
    if (_hintRequests % 2 == 1) {
      _hintCount++;
    }
    notifyListeners();
  }

  void hideHints() {}

  Map<String, dynamic> toSnapshot() => {
    'levelId': level.id,
    'swapCount': _swapCount,
    'checkCount': _checkCount,
    'hintCount': _hintCount,
    'hintRequests': _hintRequests,
    'solved': _solved,
    'elapsedMs': elapsed.inMilliseconds,
  };

  PuzzleState copyWithReset() {
    return PuzzleState(level: level);
  }
}
