import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/level.dart';
import '../models/puzzle_state.dart';
import '../models/route_arguments.dart';
import '../models/score_result.dart';
import '../services/corpus_service.dart';
import '../services/persistence_service.dart';
import '../services/placement_sound.dart';
import '../services/scoring_service.dart';
import '../services/session_block.dart';
import '../widgets/block_progress.dart';
import '../widgets/placement_burst.dart';
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
  SceneRun? _sceneRun;
  bool _hintsVisible = false;
  bool _dragActive = false;
  bool _navLock = false;
  int? _selectedIndex;
  int? _lensRuIndex;
  ScoreResult? _scoreResult;
  String? _saveError;
  int _lastReward = 0;
  int _rewardTick = 0;

  // Placement celebration: one flash per chip that the PLAYER moved into
  // its correct place for the first time in this run. Keyed by token id,
  // independent of the score bookkeeping above.
  final Set<int> _celebratedTokenIds = {};
  int? _burstTokenId;
  int _burstSerial = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_puzzle != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    Level? level;
    if (args is PreLearnResult) {
      _prelearn = args;
      level = args.level;
    } else if (args is SceneRun) {
      _sceneRun = args;
      level = args.levels[args.index];
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
    final tokens = puzzle.tokens;
    if (from < 0 || from >= tokens.length) return;

    final moved = tokens[from];
    final wasCorrect = puzzle.isPositionCorrect(from);
    final reward = puzzle.moveToken(from, to);
    if (reward < 0) return;

    // Celebrate the chip the PLAYER placed: it must have moved from a
    // wrong position into a right one, for the first time in this run.
    // Text-based checks match what the player sees (duplicate chips).
    final shouldCelebrate =
        !puzzle.solved &&
        !wasCorrect &&
        puzzle.isPositionCorrect(to) &&
        _celebratedTokenIds.add(moved.id);

    setState(() {
      _selectedIndex = null;
      _hintsVisible = false;
      _lensRuIndex = null;
      if (reward > 0) {
        _lastReward = reward * ScoringService.placementPoints;
        _rewardTick++;
      }
      _burstTokenId = shouldCelebrate ? moved.id : null;
      if (shouldCelebrate) _burstSerial++;
    });
    // The +N badge is temporary: it disappears shortly after the move
    // instead of hanging there until the end of the level.
    if (reward > 0) {
      final tick = _rewardTick;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _rewardTick == tick) {
          setState(() => _lastReward = 0);
        }
      });
    }

    if (shouldCelebrate) {
      // Fire and forget: audio failure must never interrupt the puzzle.
      context.read<PlacementAudio>().playCorrectPlacement();
    }
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
      _lensRuIndex = null;
      _burstTokenId = null;
    });
  }

  Future<void> _onSolved() async {
    final puzzle = _puzzle!;
    final prelearn = _prelearn;
    final persistence = context.read<PersistenceService>();
    // A solved phrase fills one segment of the current block in the
    // regular Play flow only; scenes have their own progress. Stats are
    // still saved below in both modes.
    if (_sceneRun == null) {
      context.read<SessionBlock>().registerSolved();
    }

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
    // A double-tap must not push the next route twice while the profile is
    // being read asynchronously.
    if (_navLock) return;
    _navLock = true;
    try {
      // Scene run: the next step is the next scene puzzle or the finale.
      final run = _sceneRun;
      if (run != null) {
        if (run.index + 1 < run.levels.length) {
          Navigator.pushReplacementNamed(
            context,
            '/puzzle',
            arguments: SceneRun(
              scene: run.scene,
              levels: run.levels,
              index: run.index + 1,
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/sceneComplete');
        }
        return;
      }
      // The block is finished: show the explicit finish line instead of
      // silently starting phrase six.
      if (context.read<SessionBlock>().isBlockComplete) {
        Navigator.pushReplacementNamed(context, '/blockComplete');
        return;
      }
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
    } finally {
      if (mounted) setState(() => _navLock = false);
    }
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    if (puzzle == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final block = context.watch<SessionBlock>();
    final lensTargets = _lensTargets(puzzle);

    return Scaffold(
      appBar: AppBar(
        title: _sceneRun != null
            ? Text(
                '${_sceneRun!.scene.titleRu} · '
                '${_sceneRun!.index + 1}/${_sceneRun!.levels.length}',
              )
            : const Text(PuzzleScreen.title),
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
            BlockProgress(
              solved: block.solvedInBlock,
              total: SessionBlock.blockSize,
            ),
            const SizedBox(height: 16),
            _buildRussianClue(puzzle, lensTargets),
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

  /// ru clue index -> set of linked chip ids. Computed once per build.
  Map<int, Set<int>> _lensTargets(PuzzleState puzzle) {
    final targets = <int, Set<int>>{};
    for (final link in puzzle.level.alignment?.links ?? const []) {
      (targets[link.ru] ??= <int>{}).add(link.en);
    }
    return targets;
  }

  Widget _buildClueToken(String word, int index, Map<int, Set<int>> targets,
      bool lensAvailable) {
    final hasLinks = lensAvailable && targets.containsKey(index);
    final active = hasLinks && _lensRuIndex == index;
    return GestureDetector(
      onTap: hasLinks
          ? () => setState(() {
                _lensRuIndex = active ? null : index;
              })
          : null,
      child: Text(
        word,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: active ? Colors.orange[800] : Colors.deepPurple[700],
          decoration: hasLinks ? TextDecoration.underline : null,
          decorationColor: active ? Colors.orange[400] : Colors.deepPurple[200],
          decorationThickness: 1.5,
        ),
      ),
    );
  }

  Widget _buildRussianClue(PuzzleState puzzle,
      Map<int, Set<int>> lensTargets) {
    final lensAvailable = puzzle.level.alignment != null && !puzzle.solved;
    final words = puzzle.level.russian.split(RegExp(r'\s+'))
      ..removeWhere((t) => t.isEmpty);
    // A word is anything containing a letter (Dart \w is ASCII-only and
    // would misclassify every Cyrillic word as punctuation).
    final letter = RegExp(r'[A-Za-zА-Яа-яЁё]');
    final terminalMarks = {'.', '!', '?', '…', '...', '?!', '!?'};
    final last = words.length - 1;
    final hasSeparateMark =
        words.length > 1 && terminalMarks.contains(words[last]);
    final lastWord = hasSeparateMark ? last - 1 : last;

    // The clue keeps its original token indices: only DISPLAY changes. The
    // last word and its terminal mark are glued into one element so the
    // mark never sits alone with a gap on a wrapped line.
    Widget clueToken(int i) => _buildClueToken(words[i], i, lensTargets,
        lensAvailable);
    final children = <Widget>[
      for (var i = 0; i <= lastWord; i++)
        if (hasSeparateMark && i == lastWord)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              clueToken(i),
              Text(
                words[last],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple[700],
                ),
              ),
            ],
          )
        else
          clueToken(i),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
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
            _buildToken(puzzle, tokens, i, lensTargets),
          if (puzzle.solved && puzzle.terminalPunctuation.isNotEmpty)
            Text(
              puzzle.terminalPunctuation,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (!puzzle.solved) _buildEndZone(puzzle),
        ],
      ),
    );
  }

  /// Drop zone at the end of the sentence: accepts any word except the one
  /// already in the last movable slot and inserts it right before the
  /// terminal punctuation. The punctuation itself stays static. The zone is
  /// padded generously in every direction and reserves the marker slot up
  /// front, so aiming near the punctuation works and nothing shifts when a
  /// drag starts.
  Widget _buildEndZone(PuzzleState puzzle) {
    final lastIndex = puzzle.tokens.length - 1;
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final from = puzzle.tokens.indexWhere((t) => t.id == details.data);
        return from >= 0 && from != lastIndex;
      },
      onAcceptWithDetails: (details) {
        final from = puzzle.tokens.indexWhere((t) => t.id == details.data);
        if (from >= 0 && from != lastIndex) {
          _move(from, lastIndex);
        }
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reserved marker slot: bright only while the zone is actually
              // accepting the drag. A faint always-on line would promise a
              // drop the zone might not take.
              Container(
                key: const ValueKey('end-zone-marker'),
                width: 5,
                height: 32,
                margin: const EdgeInsets.only(right: 2),
                color: hovering
                    ? Colors.blue
                    : _dragActive
                        ? Colors.blue.withValues(alpha: 0.35)
                        : Colors.transparent,
              ),
              Text(
                puzzle.terminalPunctuation,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToken(PuzzleState puzzle, List<PuzzleToken> tokens, int index,
      Map<int, Set<int>> lensTargets) {
    final token = tokens[index];
    final state = _stateFor(puzzle, index);
    // Lens channel (amber underline), independent of the state above and
    // addressed by token id so it follows chips through every shuffle.
    final translated = _lensRuIndex != null &&
        (lensTargets[_lensRuIndex]?.contains(token.id) ?? false);

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
        final chip = withPlacementBurst(
          chip: WordToken(
            word: token.text,
            state: state,
            translated: translated,
            dropSide: side,
          ),
          active: _burstTokenId == token.id,
          serial: _burstSerial,
        );
        return Draggable<int>(
          data: token.id,
          onDragStarted: () => setState(() {
            _selectedIndex = null;
            _dragActive = true;
          }),
          onDragEnd: (_) => setState(() => _dragActive = false),
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
        // Wrap instead of Row: on narrow screens the chips would overflow.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text('Moves: ${puzzle.moveCount}')),
            Chip(label: Text('Hints: ${puzzle.hintCount}')),
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
                    formatResultSentence(puzzle.level.russian),
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
              onPressed: _navLock ? null : _handleNext,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                _sceneRun != null
                    ? (_sceneRun!.index + 1 >= _sceneRun!.levels.length
                        ? 'Finish scene'
                        : 'Next phrase')
                    : context.watch<SessionBlock>().isBlockComplete
                    ? 'See block results'
                    : 'Next sentence',
              ),
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

/// Strips the horizontal gap before a separately written terminal mark
/// when a sentence is DISPLAYED (data and chip indices stay untouched).
String formatResultSentence(String raw) {
  final text = raw.trimRight();
  final separatedMark = RegExp(r'[ \t\u00A0]+(\.\.\.|…|\?!|!\?|[.!?])$');
  return text.replaceFirstMapped(separatedMark, (m) => m.group(1)!);
}
