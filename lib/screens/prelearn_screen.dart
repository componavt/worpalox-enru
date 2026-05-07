import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/level.dart';
import '../models/route_arguments.dart';
import '../services/corpus_service.dart';
import '../services/persistence_service.dart';

class PreLearnScreen extends StatefulWidget {
  const PreLearnScreen({super.key});

  @override
  State<PreLearnScreen> createState() => _PreLearnScreenState();
}

class _PreLearnScreenState extends State<PreLearnScreen> {
  Level? _initialLevel;
  Level? _currentLevel;
  int _currentIndex = 0;
  List<_QuestionPair> _questions = [];
  int _correctAnswers = 0;
  bool _completed = false;
  bool _skipped = false;
  bool _showingFeedback = false;

  @override
  void initState() {
    super.initState();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Level) {
      _initialLevel = args;
    }
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    final corpusService = Provider.of<CorpusService>(
      context,
      listen: false,
    );
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );

    // Use initial level if provided (from home screen "Continue"), otherwise select new
    Level? nextLevel = _initialLevel;
    if (nextLevel == null) {
      final profile = await persistenceService.loadActiveProfile();
      if (profile != null) {
        nextLevel = corpusService.getNextLevelForProfile(profile);
      }
      if (nextLevel == null && corpusService.playableLevels.isNotEmpty) {
        nextLevel = corpusService.playableLevels.first;
      }
    }

    if (nextLevel == null) {
      _showError('No levels available');
      return;
    }

    final levelToUse = nextLevel;
    setState(() {
      _currentLevel = levelToUse;
      _prepareQuestions(levelToUse);
    });
  }

  void _prepareQuestions(Level level) {
    final pairs = level.prelearnPairs;
    if (pairs.isEmpty) {
      _questions = [];
      return;
    }

    final allEnglishTokens = level.english
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();

    _questions = pairs.map((pair) {
      final distractors = allEnglishTokens
          .where((t) => t != pair.en && t.isNotEmpty)
          .toList();

      while (distractors.length < 3) {
        distractors.add('word${distractors.length + 1}');
      }

      return _QuestionPair(
        correctEn: pair.en,
        correctRu: pair.ru,
        options: [pair.en, ...distractors.take(3)]..shuffle(),
      );
    }).toList();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleAnswer(String selected, String correct) {
    final isCorrect = selected == correct;
    setState(() {
      if (isCorrect) {
        _correctAnswers++;
      }
      _showingFeedback = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _currentIndex++;
          _showingFeedback = false;
          if (_currentIndex >= _questions.length) {
            _completed = true;
          }
        });
      }
    });
  }

  void _handleSkip() {
    setState(() {
      _skipped = true;
      _completed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLevel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/puzzle',
            arguments: PreLearnResult(
              level: _currentLevel!,
              correctAnswers: _correctAnswers,
              totalQuestions: _questions.length,
              skipped: _skipped,
            ),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/puzzle',
            arguments: PreLearnResult(
              level: _currentLevel!,
              correctAnswers: 0,
              totalQuestions: 0,
              skipped: true,
            ),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentIndex >= _questions.length) {
      setState(() => _completed = true);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Words'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 32),
            Text(
              'Find the English word for:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                question.correctRu,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final option in question.options)
                  _buildOption(option, question.correctEn),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _handleSkip,
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip Pre-learning'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String text, String correct) {
    final isSelected = _showingFeedback;
    final isCorrect = text == correct;

    Color? buttonColor;
    IconData? icon;

    if (isSelected) {
      if (isCorrect) {
        buttonColor = Colors.green;
        icon = Icons.check;
      } else {
        buttonColor = Colors.red;
        icon = Icons.close;
      }
    }

    return ElevatedButton(
      onPressed: _showingFeedback ? null : () => _handleAnswer(text, correct),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: buttonColor,
        disabledBackgroundColor: buttonColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 16)),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
        ],
      ),
    );
  }
}

class _QuestionPair {
  final String correctEn;
  final String correctRu;
  final List<String> options;

  _QuestionPair({
    required this.correctEn,
    required this.correctRu,
    required this.options,
  });
}


