import 'package:flutter/foundation.dart';

/// Tracks progress toward the current play block: five solved phrases
/// complete a block and the player sees an explicit finish line.
///
/// Session-scoped on purpose: a half-finished block does not survive an
/// app restart, keeping the first version simple.
class SessionBlock extends ChangeNotifier {
  static const int blockSize = 5;

  int _solvedInBlock = 0;

  /// Phrases solved since the current block started (0..[blockSize]).
  int get solvedInBlock => _solvedInBlock;

  /// True once the current block has been completed and not yet reset.
  bool get isBlockComplete => _solvedInBlock >= blockSize;

  /// Registers one successfully completed phrase. Re-registering after the
  /// block is already complete is ignored; the completion screen resets it.
  void registerSolved() {
    if (_solvedInBlock < blockSize) {
      _solvedInBlock++;
      notifyListeners();
    }
  }

  /// Starts a fresh block after the completion screen.
  void startNextBlock() {
    _solvedInBlock = 0;
    notifyListeners();
  }
}
