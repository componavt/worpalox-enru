import 'dart:async';

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
  bool _navLock = false;
  int? _selectedIndex;
  int? _lensRuIndex;
  ScoreResult? _scoreResult;
  String? _saveError;
  int _lastReward = 0;
  int _rewardTick = 0;

  // Placement celebration: one flash per chip the player locked (placed
  // correctly; green and immovable afterwards). Keyed by token id.
  int? _burstTokenId;
  int _burstSerial = 0;

  // Field-level drag controller: ONE target for the whole sentence; the
  // insertion gap is chosen from the pointer position with an 8 px
  // hysteresis band, and the commit always uses the shown gap. Token keys
  // provide the gap coordinates.
  final Map<int, GlobalKey> _tokenKeys = {};

  /// The insertion gap chosen by the drag controller. A ValueNotifier so
  /// the markers update WITHOUT rebuilding the whole screen mid-drag.
  final ValueNotifier<int?> _activeGap = ValueNotifier<int?>(null);

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
    _puzzle = PuzzleState(level: level, locking: true);
  }

  Timer? _rewardClearTimer;

  @override
  void dispose() {
    _rewardClearTimer?.cancel();
    _activeGap.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  void _move(int from, int to) {
    final puzzle = _puzzle!;
    final tokens = puzzle.tokens;
    if (from < 0 || from >= tokens.length) return;

    final moved = tokens[from];
    final reward = puzzle.moveToken(from, to);
    if (reward < 0) return;

    // The lock event is the celebration: the chip the player placed is
    // correct and immovable now.
    final lockedNow = puzzle.newlyLockedSlot != null;

    _activeGap.value = null;
    setState(() {
      _selectedIndex = null;
      _hintsVisible = false;
      _lensRuIndex = null;
      if (reward > 0) {
        _lastReward = reward * ScoringService.placementPoints;
        _rewardTick++;
      }
      _burstTokenId = lockedNow ? moved.id : null;
      if (lockedNow) _burstSerial++;
    });
    // The +N badge is temporary: it disappears shortly after the move
    // instead of hanging there until the end of the level.
    if (reward > 0) {
      final tick = _rewardTick;
      _rewardClearTimer?.cancel();
      _rewardClearTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _rewardTick == tick) {
          setState(() => _lastReward = 0);
        }
      });
    }

    if (lockedNow) {
      // Fire and forget: audio failure must never interrupt the puzzle.
      context.read<PlacementAudio>().playCorrectPlacement();
    }
    if (puzzle.solved) _onSolved();
  }

  void _handleTap(int index) {
    if (_puzzle!.solved || _puzzle!.isSlotLocked(index)) return;
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
    _activeGap.value = null;
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
        lockingMode: puzzle.lockingEnabled,
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
            _buildSentence(puzzle, lensTargets),
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
    if (puzzle.isSlotLocked(index)) return WordTokenState.locked;
    if (_selectedIndex == index) return WordTokenState.selected;
    if (_hintsVisible) {
      return puzzle.isPositionCorrect(index)
          ? WordTokenState.hintCorrect
          : WordTokenState.hintWrong;
    }
    return WordTokenState.normal;
  }

  Widget _buildSentence(PuzzleState puzzle, Map<int, Set<int>> lensTargets) {
    final tokens = puzzle.tokens;
    final body = Wrap(
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
      ],
    );

    final field = Container(
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
      child: body,
    );

    if (puzzle.solved) return field;

    // ONE drag target for the whole sentence: the insertion gap is chosen
    // from the pointer position with hysteresis, the marker shows exactly
    // that gap, and the commit uses the same gap. No per-chip competition,
    // no "rejected neighbour" gap without an acceptor.
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final from = puzzle.tokens.indexWhere((t) => t.id == details.data);
        if (from < 0) return false;
        return _computeGap(details.offset, puzzle) != null;
      },
      onAcceptWithDetails: (details) {
        final from = puzzle.tokens.indexWhere((t) => t.id == details.data);
        if (from < 0) return;
        final gap = _computeGap(details.offset, puzzle);
        if (gap == null) return;
        _move(from, gap);
      },
      builder: (context, candidates, _) => field,
    );
  }

  /// Computes the insertion gap for the pointer: nearest valid gap point,
  /// with an 8 px hysteresis band around the previously shown gap. Locked
  /// slots and empty coordinates are not valid gaps.
  int? _computeGap(Offset pointer, PuzzleState puzzle) {
    final n = puzzle.tokens.length;
    if (n == 0) return null;
    // Candidate insertion points: (destination slot, screen point). Both
    // edges of a chip map to a destination; "after the last chip" maps to
    // the last free slot (destination n-1), never out of range.
    final candidates = <({int dest, Offset point})>[];
    for (var i = 0; i < n; i++) {
      if (puzzle.isSlotLocked(i)) continue;
      final box =
          _tokenKeys[puzzle.tokens[i].id]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final midY = box.size.height / 2;
      candidates.add((dest: i, point: topLeft + Offset(-2, midY)));
      final destAfter = i + 1 < n ? i + 1 : n - 1;
      candidates.add(
        (dest: destAfter, point: topLeft + Offset(box.size.width + 2, midY)),
      );
    }
    if (candidates.isEmpty) return null;

    int? nearest;
    double best = double.infinity;
    for (final c in candidates) {
      final d = (c.point - pointer).distance;
      if (d < best) {
        best = d;
        nearest = c.dest;
      }
    }
    // Hysteresis: while the pointer stays within 8 px of the previously
    // shown gap point, keep that destination even if another became
    // marginally closer.
    final previous = _activeGap.value;
    if (previous != null && previous != nearest) {
      for (final c in candidates) {
        if (c.dest == previous && (c.point - pointer).distance <= 8) {
          return previous;
        }
      }
    }
    return nearest;
  }

  /// During play interchangeable articles are shown lowercase (removes the
  /// false the/The distinction); the victory card shows the original text.
  String _chipLabel(PuzzleToken token) {
    final lower = token.text.toLowerCase();
    if (const {'the', 'a', 'an'}.contains(lower)) return lower;
    return token.text;
  }

  Widget _buildToken(PuzzleState puzzle, List<PuzzleToken> tokens, int index,
      Map<int, Set<int>> lensTargets) {
    final token = tokens[index];
    final state = _stateFor(puzzle, index);
    final translated = _lensRuIndex != null &&
        (lensTargets[_lensRuIndex]?.contains(token.id) ?? false);
    final label = _chipLabel(token);

    if (puzzle.solved || puzzle.isSlotLocked(index)) {
      // Locked chips are green and immovable: no drag source, no target.
      // The lens channel survives locking (the link remains meaningful).
      return withPlacementBurst(
        chip: WordToken(word: label, state: state, translated: translated),
        active: _burstTokenId == token.id,
        serial: _burstSerial,
      );
    }

    final chipKey = _tokenKeys.putIfAbsent(token.id, () => GlobalKey());

    // Gap markers listen to the gap notifier directly: no full-screen
    // rebuild while the drag is in progress.
    return ValueListenableBuilder<int?>(
      valueListenable: _activeGap,
      builder: (context, gap, _) {
        var side = DropSide.none;
        if (gap != null) {
          if (gap == index) side = DropSide.before;
          if (gap == index + 1) side = DropSide.after;
        }
        final chip = KeyedSubtree(
          key: chipKey,
          child: withPlacementBurst(
            chip: WordToken(
              word: label,
              state: state,
              translated: translated,
              dropSide: side,
            ),
            active: false,
            serial: _burstSerial,
          ),
        );
        return Draggable<int>(
          data: token.id,
          onDragStarted: () => setState(() {
            _selectedIndex = null;
          }),
          onDragEnd: (_) {},
          feedback: Material(
            color: Colors.transparent,
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: WordToken(word: label, state: WordTokenState.selected),
          ),
          childWhenDragging: WordToken(word: label, faded: true),
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
  final text = raw.trim();
  // Commas and terminal marks attach to the preceding word in these
  // display strings; inner tokens and data stay untouched.
  final withoutCommaGaps =
      text.replaceAll(RegExp(r'[ \t\u00A0]+(?=,)'), '');
  final separatedMark = RegExp(r'[ \t\u00A0]+(\.\.\.|…|\?!|!\?|[.!?])$');
  return withoutCommaGaps.replaceFirstMapped(
      separatedMark, (m) => m.group(1)!);
}
