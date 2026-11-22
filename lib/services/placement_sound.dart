import 'package:flutter/foundation.dart' show debugPrint;

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One selectable sound of the test Sound Lab (Kenney "Interface Sounds",
/// CC0 — see THIRD_PARTY_ASSETS.md).
class PlacementSound {
  final String id;
  final String label;
  final String asset; // relative to the assets/ directory

  const PlacementSound(this.id, this.label, this.asset);
}

/// Drop 003 stays as the control sample the owner did not reject; the
/// other seven Interface Sounds were removed from the assets and catalog.
const placementSounds = [
  PlacementSound('drop_003', 'Drop 003 (control)', 'audio/lab/drop_003.ogg'),
  PlacementSound('impact_generic_light', 'Soft Tap',
      'audio/lab/impact_generic_light_000.ogg'),
  PlacementSound('impact_wood_medium', 'Wood Tap',
      'audio/lab/impact_wood_medium_003.ogg'),
  PlacementSound('impact_glass_light', 'Glass Tick',
      'audio/lab/impact_glass_light_000.ogg'),
  PlacementSound('soft_pop', 'Soft Pop', 'audio/lab/soft_pop.wav'),
  PlacementSound('two_note_soft', 'Two-note Soft', 'audio/lab/two_note_soft.wav'),
];

const offSoundId = 'off';

/// A saved choice that no longer exists in the catalog (removed sample,
/// upgraded build) resolves to Off instead of a silent dead reference.
String resolvePlacementSoundId(String? savedId) {
  if (savedId == null || savedId == offSoundId) return offSoundId;
  for (final sound in placementSounds) {
    if (sound.id == savedId) return savedId;
  }
  return offSoundId;
}

/// Audio for the placement celebration: one short sound, no overlays.
///
/// The abstract surface lets tests substitute a fake that counts calls;
/// the real implementation plays through a single AudioPlayer and swallows
/// every audio failure so the puzzle never waits for sound.
abstract class PlacementAudio {
  String get selectedId;
  Future<void> select(String id); // a catalog id or [offSoundId]
  Future<void> preview(PlacementSound sound);
  Future<void> stopPreview();
  Future<void> playCorrectPlacement();
}

class SoundService implements PlacementAudio {
  /// Test hook: when set, the confirmed sound is handed here instead of
  /// the player (no platform channels in tests).
  void Function(PlacementSound sound, double volume)? onEmit;

  static const _prefKey = 'placement_sound_id';
  static const _cooldown = Duration(milliseconds: 150);
  static const _volume = 0.22;

  final AudioPlayer _player = AudioPlayer();
  String _selectedId = offSoundId;
  bool _busy = false;
  DateTime _lastPlay = DateTime.fromMillisecondsSinceEpoch(0);

  SoundService() {
    // The busy flag is released by natural completion, explicit stop or
    // an error — a fixed timer alone cannot guarantee the rule
    // "a new gameplay sound never interrupts the current one".
    _player.onPlayerComplete.listen((_) {
      _busy = false;
    });
  }

  @override
  String get selectedId => _selectedId;

  PlacementSound? get selectedSound {
    for (final sound in placementSounds) {
      if (sound.id == _selectedId) return sound;
    }
    return null; // 'off' or an unknown id: silence
  }

  /// Loads the persisted choice; call once during app start.
  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedId = resolvePlacementSoundId(prefs.getString(_prefKey));
  }

  @override
  Future<void> select(String id) async {
    _selectedId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
    if (id == offSoundId) {
      await stopPreview();
    }
  }

  @override
  Future<void> preview(PlacementSound sound) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(sound.asset), volume: _volume);
    } catch (e) {
      debugPrint('preview failed: $e');
    }
  }

  @override
  Future<void> stopPreview() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('stop failed: $e');
    }
  }

  @override
  Future<void> playCorrectPlacement() async {
    final sound = selectedSound;
    // In-game rule: if the previous sample is still starting or playing,
    // the new request is skipped — gameplay sounds never arrive late.
    if (sound == null || _busy) return;
    final now = DateTime.now();
    if (now.difference(_lastPlay) < _cooldown) return;
    _busy = true;
    _lastPlay = now;
    try {
      final emit = onEmit;
      if (emit != null) {
        emit(sound, _volume);
        _busy = false;
      } else {
        // No stop() after play: the sample must finish naturally; the
        // onPlayerComplete listener releases the busy flag.
        await _player.play(AssetSource(sound.asset), volume: _volume);
      }
    } catch (e) {
      debugPrint('play failed: $e');
      _busy = false;
    }
  }

  void disposeService() {
    _player.dispose();
  }
}
