/// Represents a local player profile for single-device multiplayer support.
import 'stats.dart';

class PlayerProfile {
  final String id;
  final String name;
  final DateTime createdAt;
  DateTime lastPlayedAt;
  final Stats stats;

  PlayerProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? lastPlayedAt,
    Stats? stats,
  }) : lastPlayedAt = lastPlayedAt ?? DateTime.now(),
       stats = stats ?? Stats();

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      stats: json['stats'] != null
          ? Stats.fromJson(json['stats'] as Map<String, dynamic>)
          : Stats(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'lastPlayedAt': lastPlayedAt.toIso8601String(),
    'stats': stats.toJson(),
  };

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
