import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/level.dart';
import '../models/player_profile.dart';
import '../models/stats.dart';
import 'difficulty_service.dart';

/// Loads and provides access to playable levels with adaptive selection.
///
/// Adaptive strategy:
/// - Random selection from allowed difficulty pool
/// - Avoid recently seen levels (last 20)
/// - Avoid repeating solved levels when possible
/// - Gradually relax constraints if pool is exhausted
class CorpusService {
  final DifficultyService _difficultyService = DifficultyService();

  List<Level> _allLevels = [];
  List<Level> _playableLevels = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/corpus/levels.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _allLevels = jsonList.map((j) => Level.fromJson(j)).toList();
      _playableLevels = _allLevels
          .where((l) => l.tokenCount >= 3 && l.tokenCount <= 8)
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

  List<Level> getEligibleLevelsForProfile(
    PlayerProfile profile, {
    int recentWindow = 20,
  }) {
    final stats = profile.stats;
    final allowedDifficulties = _difficultyService
        .getAllowedDifficultiesForProfile(stats);

    final recentIds = stats.recentLevelIds.length > recentWindow
        ? stats.recentLevelIds.sublist(
            stats.recentLevelIds.length - recentWindow,
          )
        : stats.recentLevelIds;

    final eligible = _playableLevels.where((level) {
      if (!allowedDifficulties.contains(level.difficulty)) {
        return false;
      }
      return true;
    }).toList();

    final notRecent = eligible.where((level) {
      return !recentIds.contains(level.id);
    }).toList();

    if (notRecent.isNotEmpty) {
      return notRecent;
    }

    return eligible;
  }

  Level? getNextLevelForProfile(PlayerProfile profile) {
    final eligible = getEligibleLevelsForProfile(profile);
    if (eligible.isEmpty) return null;

    final random = Random();
    return eligible[random.nextInt(eligible.length)];
  }

  Level? getLevelByDifficulty(String difficulty) {
    final matching = _playableLevels
        .where((l) => l.difficulty == difficulty)
        .toList();
    if (matching.isEmpty) return null;
    final random = Random();
    return matching[random.nextInt(matching.length)];
  }

  bool isLevelRepeatTooRecent(
    Level level,
    Stats stats, {
    int recentWindow = 10,
  }) {
    final recentIds = stats.recentLevelIds.length > recentWindow
        ? stats.recentLevelIds.sublist(
            stats.recentLevelIds.length - recentWindow,
          )
        : stats.recentLevelIds;
    return recentIds.contains(level.id);
  }
}
