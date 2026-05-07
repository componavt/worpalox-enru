import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stats.dart';
import '../models/player_profile.dart';

/// Versioned persistence schema for profiles and progress.
///
/// Schema v2:
/// {
///   "schemaVersion": 2,
///   "activeProfileId": "default",
///   "profiles": [
///     {
///       "id": "default",
///       "name": "Player 1",
///       "createdAt": "...",
///       "lastPlayedAt": "...",
///       "stats": { ... }
///     }
///   ]
/// }
class PersistenceService {
  static const _key = 'worpalox_save_v2';
  static const _schemaVersion = 2;
  static const _oldKey = 'worpalox_save_v1';

  Future<Map<String, dynamic>> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (data['schemaVersion'] == _schemaVersion) {
          return data;
        }
      } catch (e) {}
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
      final oldStatsJson = oldData['stats'] as Map<String, dynamic>? ?? {};
      final oldTotalSolved = oldStatsJson['totalSolved'] as int? ?? 0;
      final oldLevelsCompleted =
          (oldStatsJson['levelsCompleted'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [];

      final defaultProfile = PlayerProfile(
        id: 'default',
        name: 'Player 1',
        createdAt: DateTime.now(),
        stats: Stats(
          totalGameScore: oldTotalSolved * 50,
          learningProgress: oldTotalSolved * 30,
          totalSolvedRuns: oldTotalSolved,
          uniqueSolvedLevelIds: oldLevelsCompleted,
          totalSwaps: oldStatsJson['totalSwaps'] as int? ?? 0,
          totalChecks: oldStatsJson['totalChecks'] as int? ?? 0,
          totalHints: oldStatsJson['totalHints'] as int? ?? 0,
          problemWords:
              (oldStatsJson['problemWords'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as int),
              ) ??
              {},
        ),
      );

      return {
        'schemaVersion': _schemaVersion,
        'activeProfileId': 'default',
        'profiles': [defaultProfile.toJson()],
      };
    } catch (e) {
      return _defaultSave();
    }
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    data['schemaVersion'] = _schemaVersion;
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<List<PlayerProfile>> loadProfiles() async {
    final data = await _loadData();
    final profilesJson = data['profiles'] as List<dynamic>?;
    if (profilesJson == null) return [];
    return profilesJson
        .map((p) => PlayerProfile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfiles(List<PlayerProfile> profiles) async {
    final data = await _loadData();
    data['profiles'] = profiles.map((p) => p.toJson()).toList();
    await _saveData(data);
  }

  Future<String?> getActiveProfileId() async {
    final data = await _loadData();
    return data['activeProfileId'] as String?;
  }

  Future<void> setActiveProfileId(String? id) async {
    final data = await _loadData();
    data['activeProfileId'] = id;
    await _saveData(data);
  }

  Future<PlayerProfile> createProfile(String name) async {
    final profiles = await loadProfiles();
    final newProfile = PlayerProfile(
      id: PlayerProfile.generateId(),
      name: name,
      createdAt: DateTime.now(),
    );
    profiles.add(newProfile);
    await saveProfiles(profiles);
    return newProfile;
  }

  Future<void> renameProfile(String id, String newName) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == id);
    if (index != -1) {
      final profile = profiles[index];
      profiles[index] = PlayerProfile(
        id: profile.id,
        name: newName,
        createdAt: profile.createdAt,
        lastPlayedAt: profile.lastPlayedAt,
        stats: profile.stats,
      );
      await saveProfiles(profiles);
    }
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);

    if (profiles.isEmpty) {
      final defaultProfile = PlayerProfile(
        id: PlayerProfile.generateId(),
        name: 'Player 1',
        createdAt: DateTime.now(),
      );
      profiles.add(defaultProfile);
      await setActiveProfileId(defaultProfile.id);
    } else if (await getActiveProfileId() == id) {
      await setActiveProfileId(profiles.first.id);
    }

    await saveProfiles(profiles);
  }

  Future<PlayerProfile?> loadActiveProfile() async {
    final profiles = await loadProfiles();
    final activeId = await getActiveProfileId();
    if (activeId == null) return profiles.isNotEmpty ? profiles.first : null;
    try {
      return profiles.firstWhere((p) => p.id == activeId);
    } catch (e) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
  }

  Future<void> saveActiveProfile(PlayerProfile profile) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await saveProfiles(profiles);
    await setActiveProfileId(profile.id);
  }

  Future<void> updateActiveProfileStats(Stats stats) async {
    final profile = await loadActiveProfile();
    if (profile != null) {
      final updatedProfile = PlayerProfile(
        id: profile.id,
        name: profile.name,
        createdAt: profile.createdAt,
        lastPlayedAt: DateTime.now(),
        stats: stats,
      );
      await saveActiveProfile(updatedProfile);
    }
  }

  Future<int?> getLastPlayedLevelId() async {
    final data = await _loadData();
    return data['lastPlayedLevelId'] as int?;
  }

  Future<void> setLastPlayedLevelId(int? id) async {
    final data = await _loadData();
    data['lastPlayedLevelId'] = id;
    await _saveData(data);
  }

  Map<String, dynamic> _defaultSave() => {
    'schemaVersion': _schemaVersion,
    'activeProfileId': null,
    'profiles': [],
  };
}
