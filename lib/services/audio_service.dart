/// TODO: Audio service for TTS and SFX.
///
/// Future work:
/// - Text-to-speech for Russian clues
/// - Text-to-speech for English sentences
/// - Sound effects for swap, check, success
///
/// For MVP: no audio.
class AudioService {
  Future<void> initialize() async {}

  Future<void> speakRussian(String text) async {}

  Future<void> speakEnglish(String text) async {}

  Future<void> playSwapSound() async {}

  Future<void> playSuccessSound() async {}

  Future<void> dispose() async {}
}
