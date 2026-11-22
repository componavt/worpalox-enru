import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One selectable sound of the test Sound Lab (Kenney "Interface Sounds",
/// CC0 — see THIRD_PARTY_ASSETS.md).
class PlacementSound {
  final String id;
  final String label;
  final String asset; // relative to the assets/ directory

  const PlacementSound(this.id, this.label, this.asset);
}

const placementSounds = [
  PlacementSound('click_001', 'Click 001', 'audio/lab/click_001.ogg'),
  PlacementSound('click_002', 'Click 002', 'audio/lab/click_002.ogg'),
  PlacementSound('drop_001', 'Drop 001', 'audio/lab/drop_001.ogg'),
  PlacementSound('drop_002', 'Drop 002', 'audio/lab/drop_002.ogg'),
  PlacementSound('drop_003', 'Drop 003', 'audio/lab/drop_003.ogg'),
  PlacementSound('drop_004', 'Drop 004', 'audio/lab/drop_004.ogg'),
  PlacementSound('confirmation_001', 'Confirmation 001',
      'audio/lab/confirmation_001.ogg'),
  PlacementSound('confirmation_003', 'Confirmation 003',
      'audio/lab/confirmation_003.ogg'),
];

const offSoundId = 'off';

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

class SoundService extends ChangeNotifier implements PlacementAudio {
  static const _prefKey = 'placement_sound_id';
  static const _cooldown = Duration(milliseconds: 150);
  static const _volume = 0.22;

  final AudioPlayer _player = AudioPlayer();
  String _selectedId = offSoundId;
  bool _busy = false;
  DateTime _lastPlay = DateTime.fromMillisecondsSinceEpoch(0);

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
    _selectedId = prefs.getString(_prefKey) ?? offSoundId;
    notifyListeners();
  }

  @override
  Future<void> select(String id) async {
    _selectedId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
    if (id == offSoundId) {
      await stopPreview();
    }
    notifyListeners();
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
    if (sound == null || _busy) return;
    final now = DateTime.now();
    if (now.difference(_lastPlay) < _cooldown) return;
    _busy = true;
    _lastPlay = now;
    try {
      await _player.play(AssetSource(sound.asset), volume: _volume);
      // Give the short sample time to finish before the next placement.
      await Future<void>.delayed(_cooldown);
    } catch (e) {
      debugPrint('play failed: $e');
    } finally {
      _busy = false;
    }
  }

  void disposeService() {
    _player.dispose();
  }
}
