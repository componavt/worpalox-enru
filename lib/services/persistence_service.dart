import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/stats.dart';
import '../models/player_profile.dart';

/// Versioned persistence for profiles and progress (shared_preferences).
///
/// Schema v2:
/// {
///   "schemaVersion": 2,
///   "activeProfileId": "1714900000000",
///   "profiles": [ { "id": ..., "name": ..., "createdAt": ..., "lastPlayedAt": ..., "stats": { ... } } ]
/// }
///
/// An unreadable save is never silently overwritten: its raw text is first
/// copied to [_corruptKey] so it can be recovered.
class PersistenceService {
  static const _key = 'worpalox_save_v2';
  static const _schemaVersion = 2;
  static const _oldKey = 'worpalox_save_v1';
  static const _corruptKey = 'worpalox_save_v2_corrupt_backup';
  static const defaultProfileName = 'Player 1';

  Future<Map<String, dynamic>> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr);
        if (data is Map<String, dynamic> &&
            data['schemaVersion'] == _schemaVersion &&
            data['profiles'] is List) {
          return data;
        }
      } catch (_) {
        // Falls through to the backup below.
      }
      await prefs.setString(_corruptKey, jsonStr);
      await prefs.remove(_key);
      return _defaultSave();
    }

    final oldJsonStr = prefs.getString(_oldKey);
    if (oldJsonStr != null) {
      return _migrateFromV1(oldJsonStr);
    }

    return _defaultSave();
  }

  Map<String, dynamic> _migrateFromV1(String oldJsonStr) {
    try {
      final oldData = jsonDecode(oldJsonStr) as Map<String, dynamic>;
      final old = oldData['stats'] as Map<String, dynamic>? ?? {};
      final oldTotalSolved = (old['totalSolved'] as num?)?.toInt() ?? 0;
      final migrated = Stats.fromJson({
        ...old,
        'totalGameScore': oldTotalSolved * 50,
        'learningProgress': oldTotalSolved * 30,
        'totalSolvedRuns': oldTotalSolved,
        'uniqueSolvedLevelIds': old['levelsCompleted'],
      });
      final profile = PlayerProfile(
        id: 'default',
        name: defaultProfileName,
        createdAt: DateTime.now(),
        stats: migrated,
      );
      return {
        'schemaVersion': _schemaVersion,
        'activeProfileId': profile.id,
        'profiles': [profile.toJson()],
      };
    } catch (_) {
      return _defaultSave();
    }
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    data['schemaVersion'] = _schemaVersion;
    await prefs.setString(_key, jsonEncode(data));
  }

  List<PlayerProfile> _profilesFrom(Map<String, dynamic> data) {
    final result = <PlayerProfile>[];
    for (final p in (data['profiles'] as List? ?? const [])) {
      try {
        result.add(PlayerProfile.fromJson(p as Map<String, dynamic>));
      } catch (_) {
        // Skip a single broken profile instead of losing all of them.
      }
    }
    return result;
  }

  Future<List<PlayerProfile>> loadProfiles() async =>
      _profilesFrom(await _loadData());

  Future<String?> getActiveProfileId() async =>
      (await _loadData())['activeProfileId'] as String?;

  Future<void> setActiveProfileId(String? id) async {
    final data = await _loadData();
    data['activeProfileId'] = id;
    await _saveData(data);
  }

  /// Creates a profile and makes it active.
  Future<PlayerProfile> createProfile(String name) async {
    final data = await _loadData();
    final profiles = _profilesFrom(data);
    final trimmed = name.trim();
    final profile = PlayerProfile(
      id: PlayerProfile.generateId(),
      name: trimmed.isEmpty ? defaultProfileName : trimmed,
      createdAt: DateTime.now(),
    );
    profiles.add(profile);
    data['profiles'] = profiles.map((p) => p.toJson()).toList();
    data['activeProfileId'] = profile.id;
    await _saveData(data);
    return profile;
  }

  Future<void> deleteProfile(String id) async {
    final data = await _loadData();
    final profiles = _profilesFrom(data)..removeWhere((p) => p.id == id);
    data['profiles'] = profiles.map((p) => p.toJson()).toList();
    if (data['activeProfileId'] == id) {
      data['activeProfileId'] = profiles.isNotEmpty ? profiles.first.id : null;
    }
    await _saveData(data);
  }

  Future<PlayerProfile?> loadActiveProfile() async {
    final data = await _loadData();
    final profiles = _profilesFrom(data);
    if (profiles.isEmpty) return null;
    final activeId = data['activeProfileId'] as String?;
    return profiles.firstWhere(
      (p) => p.id == activeId,
      orElse: () => profiles.first,
    );
  }

  /// Applies [update] to the active profile's stats and saves the result.
  /// Returns the updated profile, or null if there is no profile.
  Future<PlayerProfile?> updateActiveProfileStats(
    void Function(Stats stats) update,
  ) async {
    final data = await _loadData();
    final profiles = _profilesFrom(data);
    if (profiles.isEmpty) return null;
    final activeId = data['activeProfileId'] as String?;
    var index = profiles.indexWhere((p) => p.id == activeId);
    if (index == -1) index = 0;

    final profile = profiles[index];
    update(profile.stats);
    profile.lastPlayedAt = DateTime.now();

    data['profiles'] = profiles.map((p) => p.toJson()).toList();
    data['activeProfileId'] = profile.id;
    await _saveData(data);
    return profile;
  }

  Map<String, dynamic> _defaultSave() => {
    'schemaVersion': _schemaVersion,
    'activeProfileId': null,
    'profiles': <dynamic>[],
  };
}
