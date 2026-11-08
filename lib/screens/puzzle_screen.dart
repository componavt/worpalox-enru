import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/level.dart';
import '../models/puzzle_state.dart';
import '../models/route_arguments.dart';
import '../models/score_result.dart';
import '../services/corpus_service.dart';
import '../services/persistence_service.dart';
import '../services/scoring_service.dart';
import '../widgets/word_token.dart';

/// Stage 2 of a round: restore the English word order using the Russian
/// sentence as a clue.
///
/// Controls: drag any word onto the place where it belongs, or tap a word
/// and then tap the place for it. The puzzle is checked after every move.
class PuzzleScreen extends StatefulWidget {
  static const title = 'Step 2 · Puzzle';

  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  final _scrollController = ScrollController();

  PuzzleState? _puzzle;
  PreLearnResult? _prelearn;
  bool _hintsVisible = false;
  int? _selectedIndex;
  ScoreResult? _scoreResult;
  String? _saveError;
  int _lastReward = 0;
  int _rewardTick = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_puzzle != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    Level? level;
    if (args is PreLearnResult) {
      _prelearn = args;
      level = args.level;
    } else if (args is Level) {
      level = args;
    }
    if (level == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _puzzle = PuzzleState(level: level);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  void _move(int from, int to) {
    final puzzle = _puzzle!;
    final reward = puzzle.moveToken(from, to);
    if (reward < 0) return;
    setState(() {
      _selectedIndex = null;
      _hintsVisible = false;
      if (reward > 0) {
        _lastReward = reward * ScoringService.placementPoints;
        _rewardTick++;
      }
    });
    if (puzzle.solved) _onSolved();
  }

  void _handleTap(int index) {
    if (_puzzle!.solved) return;
    final selected = _selectedIndex;
    if (selected == null) {
      setState(() => _selectedIndex = index);
    } else if (selected == index) {
      setState(() => _selectedIndex = null);
    } else {
      _move(selected, index);
    }
  }

  void _toggleHints() {
    final puzzle = _puzzle!;
    if (puzzle.solved) return;
    setState(() {
      if (_hintsVisible) {
        _hintsVisible = false;
      } else {
        puzzle.useHint();
        _hintsVisible = true;
      }
    });
  }

  void _reshuffle() {
    setState(() {
      _puzzle!.reshuffle();
      _selectedIndex = null;
      _hintsVisible = false;
    });
  }

  Future<void> _onSolved() async {
    final puzzle = _puzzle!;
    final prelearn = _prelearn;
    final persistence = context.read<PersistenceService>();

    try {
      final before = await persistence.loadActiveProfile();
      final isRepeat = before?.stats.hasSolvedLevel(puzzle.level.id) ?? false;
      final score = ScoringService().calculateScore(
        solved: true,
        moves: puzzle.moveCount,
        minMoves: puzzle.minMoves,
        placements: puzzle.placementRewards,
        hints: puzzle.hintCount,
        prelearnCorrect: prelearn?.skipped == false
            ? prelearn!.correctAnswers
            : 0,
        isRepeatLevel: isRepeat,
      );

      await persistence.updateActiveProfileStats((stats) {
        stats.totalGameScore += score.totalGameScore;
        stats.learningProgress += score.totalLearningProgress;
        stats.totalSolvedRuns++;
        stats.totalMoves += puzzle.moveCount;
        stats.totalHints += puzzle.hintCount;
        if (prelearn != null && prelearn.totalQuestions > 0) {
          if (prelearn.skipped) {
            stats.prelearnSkipped++;
          } else {
            stats.prelearnCorrect += prelearn.correctAnswers;
            stats.prelearnWrong += prelearn.wrongAnswers;
          }
        }
        stats.addSolvedLevel(puzzle.level.id);
        stats.incrementDifficultyCount(puzzle.level.difficulty);
      });

      if (!mounted) return;
      setState(() => _scoreResult = score);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Progress could not be saved: $e';
        _scoreResult = ScoreResult.failure;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleNext() async {
    final corpus = context.read<CorpusService>();
    final profile = await context
        .read<PersistenceService>()
        .loadActiveProfile();
    if (!mounted) return;
    final next = profile != null
        ? corpus.getNextLevelForProfile(profile)
        : null;
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/prelearn', arguments: next);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    if (puzzle == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(PuzzleScreen.title),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Back to menu',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRussianClue(puzzle),
            const SizedBox(height: 20),
            _buildSentence(puzzle),
            const SizedBox(height: 12),
            _buildStatus(puzzle),
            const SizedBox(height: 16),
            if (!puzzle.solved) _buildButtons(),
            if (_scoreResult != null) ...[
              const SizedBox(height: 8),
              _buildResultCard(puzzle, _scoreResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRussianClue(PuzzleState puzzle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        puzzle.level.russian,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  WordTokenState _stateFor(PuzzleState puzzle, int index) {
    if (puzzle.solved) return WordTokenState.solved;
    if (_selectedIndex == index) return WordTokenState.selected;
    if (_hintsVisible) {
      return puzzle.isPositionCorrect(index)
          ? WordTokenState.hintCorrect
          : WordTokenState.hintWrong;
    }
    return WordTokenState.normal;
  }

  Widget _buildSentence(PuzzleState puzzle) {
    final tokens = puzzle.tokens;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: puzzle.solved ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: puzzle.solved ? Colors.green[300]! : Colors.grey[300]!,
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < tokens.length; i++)
            _buildToken(puzzle, tokens, i),
          if (puzzle.terminalPunctuation.isNotEmpty)
            Text(
              puzzle.terminalPunctuation,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildToken(PuzzleState puzzle, List<PuzzleToken> tokens, int index) {
    final token = tokens[index];
    final state = _stateFor(puzzle, index);

    if (puzzle.solved) {
      return WordToken(word: token.text, state: state);
    }

    return DragTarget<int>(
      key: ValueKey(token.id),
      onWillAcceptWithDetails: (d) => d.data != token.id,
      onAcceptWithDetails: (d) {
        final from = puzzle.tokens.indexWhere((t) => t.id == d.data);
        _move(from, index);
      },
      builder: (context, candidates, _) {
        var side = DropSide.none;
        if (candidates.isNotEmpty) {
          final from = tokens.indexWhere((t) => t.id == candidates.first);
          side = from > index ? DropSide.before : DropSide.after;
        }
        final chip = WordToken(word: token.text, state: state, dropSide: side);
        return Draggable<int>(
          data: token.id,
          onDragStarted: () => setState(() => _selectedIndex = null),
          feedback: Material(
            color: Colors.transparent,
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: WordToken(word: token.text, state: WordTokenState.selected),
          ),
          childWhenDragging: WordToken(word: token.text, faded: true),
          child: GestureDetector(onTap: () => _handleTap(index), child: chip),
        );
      },
    );
  }

  Widget _buildStatus(PuzzleState puzzle) {
    if (puzzle.solved) {
      return Text(
        'Solved!',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: Colors.green[700], fontWeight: FontWeight.bold),
      );
    }
    return Column(
      children: [
        Text(
          _selectedIndex == null
              ? 'Drag a word to its place, or tap a word and then tap where it goes.'
              : 'Now tap the place for "${puzzle.tokens[_selectedIndex!].text}".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(label: Text('Moves: ${puzzle.moveCount}')),
            const SizedBox(width: 8),
            Chip(label: Text('Hints: ${puzzle.hintCount}')),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _rewardTick == 0
                  ? const SizedBox.shrink()
                  : Text(
                      '+$_lastReward',
                      key: ValueKey(_rewardTick),
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _toggleHints,
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(
            _hintsVisible
                ? 'Hide hint'
                : 'Hint (-${ScoringService.hintPenalty})',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _reshuffle,
          icon: const Icon(Icons.shuffle),
          label: const Text('Shuffle'),
        ),
      ],
    );
  }

  Widget _buildResultCard(PuzzleState puzzle, ScoreResult score) {
    final theme = Theme.of(context);
    final perfect =
        score.efficiencyBonus == ScoringService.perfectEfficiencyBonus &&
        score.hintPenalty == 0;
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.celebration, size: 48, color: Colors.green[700]),
            const SizedBox(height: 8),
            Text(
              perfect ? 'Perfect!' : 'Excellent!',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    puzzle.level.english,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    puzzle.level.russian,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (puzzle.level.commentaryRu.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  puzzle.level.commentaryRu,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.blue[900],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_saveError != null)
              Text(_saveError!, style: const TextStyle(color: Colors.red))
            else ...[
              _scoreLine('Words placed', score.placementPoints),
              _scoreLine('Solved', score.solveBonus),
              if (score.efficiencyBonus > 0)
                _scoreLine(
                  'Moves: ${puzzle.moveCount} (best ${puzzle.minMoves})',
                  score.efficiencyBonus,
                ),
              if (score.hintPenalty > 0)
                _scoreLine('Hints', -score.hintPenalty),
              const Divider(),
              Text(
                'Game Score: +${score.totalGameScore}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Learning Progress: +${score.totalLearningProgress}'
                '${score.isRepeat ? ' (repeat)' : ''}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _handleNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next sentence'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
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

  Widget _scoreLine(String label, int points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            points >= 0 ? '+$points' : '$points',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: points >= 0 ? Colors.green[800] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }
}
