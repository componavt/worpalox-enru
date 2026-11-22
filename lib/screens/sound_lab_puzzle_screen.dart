import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/puzzle_state.dart';
import '../services/placement_sound.dart';
import '../widgets/placement_burst.dart';
import '../widgets/word_token.dart';
import 'sound_lab_screen.dart' show soundLabLevel;

/// Fixed-order test puzzle for the Sound Lab: one move ("The" to the front)
/// places a chip correctly without solving the sentence, so the tester
/// hears exactly the placement sound, not a victory signal. No scores, no
/// persistence, no block progress; Reset restores the fixed start.
class SoundLabPuzzleScreen extends StatefulWidget {
  const SoundLabPuzzleScreen({super.key});

  @override
  State<SoundLabPuzzleScreen> createState() => _SoundLabPuzzleScreenState();
}

class _SoundLabPuzzleScreenState extends State<SoundLabPuzzleScreen> {
  static const _startOrder = ['flew', 'open', 'The', 'doors'];

  late PuzzleState _puzzle;
  int? _selectedIndex;
  final Set<int> _celebratedTokenIds = {};
  int? _burstTokenId;
  int _burstSerial = 0;

  @override
  void initState() {
    super.initState();
    _resetPuzzle();
  }

  void _resetPuzzle() {
    setState(() {
      _puzzle = PuzzleState.fixed(
        level: soundLabLevel(),
        order: _startOrder,
      );
      _selectedIndex = null;
      _burstTokenId = null;
      _celebratedTokenIds.clear();
    });
  }

  void _move(int from, int to) {
    final puzzle = _puzzle;
    final tokens = puzzle.tokens;
    if (from < 0 || from >= tokens.length) return;

    final moved = tokens[from];
    final wasCorrect = puzzle.isPositionCorrect(from);
    final reward = puzzle.moveToken(from, to);
    if (reward < 0) return;

    final shouldCelebrate =
        !puzzle.solved &&
        !wasCorrect &&
        puzzle.isPositionCorrect(to) &&
        _celebratedTokenIds.add(moved.id);

    setState(() {
      _selectedIndex = null;
      _burstTokenId = shouldCelebrate ? moved.id : null;
      if (shouldCelebrate) _burstSerial++;
    });

    if (shouldCelebrate) {
      context.read<PlacementAudio>().playCorrectPlacement();
    }
  }

  void _handleTap(int index) {
    if (_puzzle.solved) return;
    final selected = _selectedIndex;
    if (selected == null) {
      setState(() => _selectedIndex = index);
    } else if (selected == index) {
      setState(() => _selectedIndex = null);
    } else {
      _move(selected, index);
    }
  }

  WordTokenState _stateFor(int index) {
    if (_puzzle.solved) return WordTokenState.solved;
    if (_selectedIndex == index) return WordTokenState.selected;
    return WordTokenState.normal;
  }

  Widget _buildToken(int index) {
    final token = _puzzle.tokens[index];
    final state = _stateFor(index);

    Widget chip = WordToken(word: token.text, state: state);
    chip = withPlacementBurst(
      chip: chip,
      active: _burstTokenId == token.id,
      serial: _burstSerial,
    );
    return GestureDetector(onTap: () => _handleTap(index), child: chip);
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<PlacementAudio>();
    final currentLabel = audio.selectedId == offSoundId
        ? 'Off'
        : placementSounds
            .where((s) => s.id == audio.selectedId)
            .map((s) => s.label)
            .first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sound test · Current: $currentLabel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < _puzzle.tokens.length; i++)
                    _buildToken(i),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Move "The" to the front (drag or tap-tap) to hear the '
              'placement sound of the selected option.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetPuzzle,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset test puzzle'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to lab'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
