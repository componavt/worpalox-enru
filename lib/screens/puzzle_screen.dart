import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/level.dart';
import '../models/puzzle_state.dart';
import '../models/score_result.dart';
import '../models/route_arguments.dart';
import '../services/hint_service.dart';
import '../services/scoring_service.dart';
import '../services/persistence_service.dart';
import '../services/corpus_service.dart';
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
  ScoreResult? _scoreResult;
  bool _showingResult = false;
  bool _saved = false;
  int _prelearnCorrect = 0;
  int _prelearnTotal = 0;
  bool _prelearnSkipped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_puzzle == null) {
      _initializePuzzle();
    }
  }

  void _initializePuzzle() {
    final args = ModalRoute.of(context)?.settings.arguments;

    Level? level;

    if (args is PreLearnResult) {
      level = args.level;
      _prelearnCorrect = args.correctAnswers;
      _prelearnTotal = args.totalQuestions;
      _prelearnSkipped = args.skipped;
    } else if (args is Level) {
      level = args;
    }

    if (level == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    final levelToUse = level;

    setState(() {
      _puzzle = PuzzleState(level: levelToUse);
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
        if (!_saved) {
          _saveProgress();
        }
      } else {
        _hintsVisible = true;
      }
    });
  }

  Future<void> _calculateScore() async {
    if (_puzzle == null) return;
    final firstCheckSolved = _puzzle!.checkCount == 1;
    
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    final profile = await persistenceService.loadActiveProfile();
    final isRepeatLevel =
        profile?.stats.hasSolvedLevel(_puzzle!.level.id) ?? false;

    _scoreResult = ScoringService().calculateScore(
      swaps: _puzzle!.swapCount,
      checks: _puzzle!.checkCount,
      hints: _puzzle!.hintCount,
      solved: true,
      firstCheckSolved: firstCheckSolved,
      difficulty: _puzzle!.level.difficulty,
      prelearnCorrect: _prelearnCorrect,
      isRepeatLevel: isRepeatLevel,
    );
  }

  Future<void> _saveProgress() async {
    if (_puzzle == null || _saved) return;
    _saved = true;

    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    final profile = await persistenceService.loadActiveProfile();
    if (profile == null) return;

    final stats = profile.stats;
    stats.totalGameScore += _scoreResult!.totalGameScore;
    stats.learningProgress += _scoreResult!.totalLearningProgress;
    stats.totalSolvedRuns++;
    stats.totalSwaps += _puzzle!.swapCount;
    stats.totalChecks += _puzzle!.checkCount;
    stats.totalHints += _puzzle!.hintCount;

    if (_prelearnSkipped) {
      stats.prelearnSkipped++;
    } else {
      stats.prelearnCorrect += _prelearnCorrect;
      stats.prelearnSkipped += (_prelearnTotal - _prelearnCorrect);
    }

    stats.addSolvedLevel(_puzzle!.level.id);
    stats.incrementDifficultyCount(_puzzle!.level.difficulty);

    await persistenceService.updateActiveProfileStats(stats);
    await persistenceService.setLastPlayedLevelId(_puzzle!.level.id);
  }

  Future<void> _handleNext() async {
    final corpusService = Provider.of<CorpusService>(context, listen: false);
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    final profile = await persistenceService.loadActiveProfile();

    if (profile == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final nextLevel = corpusService.getNextLevelForProfile(profile);
    if (nextLevel == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }

    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/prelearn',
        arguments: nextLevel,
      );
  }
}


  void _handleHome() {
    Navigator.pushReplacementNamed(context, '/');
  }




  void _toggleHints() {
    if (_puzzle == null) return;
    setState(() {
      if (!_hintsVisible) {
        _puzzle!.useHint();
        _hintsVisible = true;
      } else {
        _puzzle!.hideHints();
        _hintsVisible = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_puzzle == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            if (_showingResult && _scoreResult != null) ...[
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
        ? hintService.getHintBooleans(
            _puzzle!.wordsCurrent,
            _puzzle!.wordsCorrect,
          )
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
        'Solved!',
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
            onPressed: _toggleHints,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(_hintsVisible ? 'Hide Hints' : 'Show Hints'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _puzzle = _puzzle!.copyWithReset();
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
            Icon(Icons.celebration, size: 48, color: Colors.green[700]),
            const SizedBox(height: 12),
            Text(
              'Excellent!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    _puzzle!.level.english,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _puzzle!.level.russian,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Learning Note:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _puzzle!.level.commentaryRu,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.blue[900]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Game Score: +${_scoreResult!.totalGameScore}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Learning Progress: +${_scoreResult!.totalLearningProgress}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_prelearnTotal > 0 && !_prelearnSkipped) ...[
              const SizedBox(height: 8),
              Text(
                'Pre-learning: $_prelearnCorrect/$_prelearnTotal correct',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Level'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
