import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/level.dart';

/// Loads and provides access to playable levels.
///
/// MVP strategy:
/// - Use pre-derived levels.json (curated short sentences)
/// - Filter by token count 4-8 for playable levels
/// - Sequential progression with wrap-around
class CorpusService {
  static const _minTokens = 4;
  static const _maxTokens = 8;

  List<Level> _allLevels = [];
  List<Level> _playableLevels = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/corpus/levels.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _allLevels = jsonList.map((j) => Level.fromJson(j)).toList();
      _playableLevels = _allLevels
          .where((l) =>
              l.tokenCount >= _minTokens && l.tokenCount <= _maxTokens)
          .toList();
      _loaded = true;
    } catch (e) {
      _allLevels = [];
      _playableLevels = [];
    }
  }

  List<Level> get playableLevels => _playableLevels;

  Level? getLevelById(int id) {
    try {
      return _allLevels.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }

  Level? getNextLevel(int? lastId) {
    if (_playableLevels.isEmpty) return null;
    if (lastId == null) return _playableLevels.first;
    final currentIndex = _playableLevels.indexWhere((l) => l.id == lastId);
    final nextIndex = (currentIndex + 1) % _playableLevels.length;
    return _playableLevels[nextIndex];
  }
}
