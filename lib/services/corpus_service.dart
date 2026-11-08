import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/level.dart';
import '../models/player_profile.dart';
import 'difficulty_service.dart';

/// Loads playable levels and selects the next one adaptively.
///
/// Strategy:
/// - random choice from the difficulty pool allowed for the profile
/// - avoid the most recently played levels when possible
/// - fall back to the whole pool rather than returning nothing
class CorpusService {
  static const minTokens = 3;
  static const maxTokens = 9;

  final DifficultyService _difficultyService = DifficultyService();
  final Random _random;

  List<Level> _playableLevels = [];
  List<String> _vocabulary = [];
  bool _loaded = false;
  String? _loadError;

  CorpusService({Random? random}) : _random = random ?? Random();

  bool get isLoaded => _loaded;

  /// Human-readable reason why levels could not be loaded, if any.
  String? get loadError => _loadError;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/corpus/levels.json');
      setLevels(
        (jsonDecode(jsonStr) as List)
            .map((j) => Level.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
      _loadError = null;
    } catch (e) {
      _playableLevels = [];
      _vocabulary = [];
      _loadError = 'Could not load levels: $e';
    }
    _loaded = true;
  }

  /// Replaces the level set (used by [load] and by tests).
  void setLevels(List<Level> levels) {
    _playableLevels = levels
        .where((l) => l.tokenCount >= minTokens && l.tokenCount <= maxTokens)
        .toList();
    final seen = <String>{};
    _vocabulary = [
      for (final level in levels)
        for (final pair in level.prelearnPairs)
          if (seen.add(pair.en.toLowerCase())) pair.en.toLowerCase(),
    ];
    _loaded = true;
  }

  List<Level> get playableLevels => List.unmodifiable(_playableLevels);

  /// Lower-case English words from all pre-learning pairs. Used as
  /// distractors in the Learn Words stage.
  List<String> get vocabulary => List.unmodifiable(_vocabulary);

  List<Level> getEligibleLevelsForProfile(PlayerProfile profile) {
    final stats = profile.stats;
    final allowed = _difficultyService
        .getAllowedDifficultiesForProfile(stats)
        .toSet();

    var pool = _playableLevels
        .where((l) => allowed.contains(l.difficulty))
        .toList();
    if (pool.isEmpty) pool = _playableLevels.toList();

    // Avoid recent levels, but keep at least a few candidates so that a
    // small pool does not collapse to a fixed rotation.
    final recent = stats.recentLevelIds;
    for (var window = recent.length; window >= 0; window--) {
      final recentIds = recent.sublist(recent.length - window).toSet();
      final fresh = pool.where((l) => !recentIds.contains(l.id)).toList();
      if (fresh.isNotEmpty && fresh.length >= min(3, pool.length - 1)) {
        return fresh;
      }
    }
    return pool;
  }

  Level? getNextLevelForProfile(PlayerProfile profile) {
    final eligible = getEligibleLevelsForProfile(profile);
    if (eligible.isEmpty) return null;
    return eligible[_random.nextInt(eligible.length)];
  }
}
