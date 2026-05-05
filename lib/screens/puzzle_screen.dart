import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/level.dart';
import '../models/puzzle_state.dart';
import '../services/hint_service.dart';
import '../services/scoring_service.dart';
import '../services/persistence_service.dart';
import '../widgets/word_token.dart';
import '../widgets/swap_button.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  PuzzleState? _puzzle;
  bool _hintsVisible = false;
  int _score = 0;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _initializePuzzle();
  }

  void _initializePuzzle() {
    final level = ModalRoute.of(context)?.settings.arguments as Level?;
    if (level == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }
    setState(() {
      _puzzle = PuzzleState(level: level);
    });
  }

  void _handleSwap(int index) {
    if (_puzzle == null || _puzzle!.solved) return;
    setState(() {
      _puzzle!.swapAdjacent(index);
    });
  }

  void _handleCheck() {
    if (_puzzle == null || _puzzle!.solved) return;
    final solved = _puzzle!.check();
    setState(() {
      if (solved) {
        _hintsVisible = false;
        _showingResult = true;
        _calculateScore();
        _saveProgress();
      } else {
        _hintsVisible = true;
      }
    });
  }

  void _calculateScore() {
    if (_puzzle == null) return;
    final firstCheckSolved = _puzzle!.checkCount == 1;
    _score = ScoringService().calculateScore(
      swaps: _puzzle!.swapCount,
      checks: _puzzle!.checkCount,
      hints: _puzzle!.hintCount,
      solved: true,
      firstCheckSolved: firstCheckSolved,
    );
  }

  Future<void> _saveProgress() async {
    if (_puzzle == null) return;
    final persistenceService =
        Provider.of<PersistenceService>(context, listen: false);
    final stats = await persistenceService.loadStats();
    stats.totalSolved++;
    stats.totalSwaps += _puzzle!.swapCount;
    stats.totalChecks += _puzzle!.checkCount;
    stats.totalHints += _puzzle!.hintCount;
    stats.levelsCompleted.add(_puzzle!.level.id);
    await persistenceService.saveStats(stats);
    await persistenceService.setLastPlayedLevelId(_puzzle!.level.id);
  }

  void _handleNext() {
    Navigator.pushReplacementNamed(context, '/prelearn');
  }

  void _handleHome() {
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    if (_puzzle == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: _handleHome,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRussianClue(),
            const SizedBox(height: 24),
            _buildWordRow(),
            const SizedBox(height: 24),
            _buildStatus(),
            const SizedBox(height: 24),
            _buildButtons(),
            if (_showingResult) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRussianClue() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Russian Clue:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _puzzle!.level.russian,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple[700],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWordRow() {
    final hintService = HintService();
    final hints = _hintsVisible
        ? hintService.getHintBooleans(_puzzle!.wordsCurrent, _puzzle!.wordsCorrect)
        : <bool>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (int i = 0; i < _puzzle!.wordsCurrent.length; i++) ...[
            if (i > 0)
              SwapButton(
                enabled: !_puzzle!.solved,
                onTap: () => _handleSwap(i - 1),
              ),
            WordToken(
              word: _puzzle!.wordsCurrent[i],
              isCorrect: _hintsVisible ? hints[i] : null,
              isSolved: _puzzle!.solved,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatus() {
    if (_puzzle!.solved) {
      return Text(
        'Solved! Score: $_score',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatChip('Swaps', '${_puzzle!.swapCount}'),
        const SizedBox(width: 12),
        _buildStatChip('Checks', '${_puzzle!.checkCount}'),
        const SizedBox(width: 12),
        _buildStatChip('Hints', '${_puzzle!.hintCount}'),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        if (!_puzzle!.solved) ...[
          ElevatedButton.icon(
            onPressed: _handleCheck,
            icon: const Icon(Icons.check),
            label: const Text('Check'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _hintsVisible = !_hintsVisible);
            },
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(_hintsVisible ? 'Hide Hints' : 'Show Hints'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _puzzle = PuzzleState(level: _puzzle!.level);
                _hintsVisible = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ],
      ],
    );
  }

  Widget _buildResultCard() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              Icons.celebration,
              size: 48,
              color: Colors.green[700],
            ),
            const SizedBox(height: 12),
            Text(
              'Excellent!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: $_score points',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green[700],
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Level'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
