import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stats.dart';

/// Versioned persistence schema for stats and progress.
///
/// Schema v1:
/// {
///   "schemaVersion": 1,
///   "stats": { ... },
///   "lastPlayedLevelId": int?
/// }
class PersistenceService {
  static const _key = 'worpalox_save_v1';
  static const _schemaVersion = 1;

  Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return _defaultSave();
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['schemaVersion'] != _schemaVersion) {
        return _defaultSave();
      }
      return data;
    } catch (e) {
      return _defaultSave();
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    data['schemaVersion'] = _schemaVersion;
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<Stats> loadStats() async {
    final data = await load();
    final statsJson = data['stats'] as Map<String, dynamic>?;
    if (statsJson == null) return Stats();
    return Stats.fromJson(statsJson);
  }

  Future<void> saveStats(Stats stats) async {
    final data = await load();
    data['stats'] = stats.toJson();
    await save(data);
  }

  Future<int?> getLastPlayedLevelId() async {
    final data = await load();
    return data['lastPlayedLevelId'] as int?;
  }

  Future<void> setLastPlayedLevelId(int? id) async {
    final data = await load();
    data['lastPlayedLevelId'] = id;
    await save(data);
  }

  Map<String, dynamic> _defaultSave() => {
        'schemaVersion': _schemaVersion,
        'stats': Stats().toJson(),
        'lastPlayedLevelId': null,
      };
}
