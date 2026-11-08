import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/level.dart';
import '../models/route_arguments.dart';
import '../services/corpus_service.dart';

/// Stage 1 of a round: quick multiple-choice warm-up on words from the
/// sentence that follows in the puzzle.
class PreLearnScreen extends StatefulWidget {
  static const title = 'Step 1 · Learn Words';

  const PreLearnScreen({super.key});

  @override
  State<PreLearnScreen> createState() => _PreLearnScreenState();
}

class _PreLearnScreenState extends State<PreLearnScreen> {
  static const _feedbackDelay = Duration(milliseconds: 900);

  Level? _level;
  List<_Question> _questions = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  String? _selected;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_level != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Level) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _level = args;
    _questions = _buildQuestions(
      args,
      context.read<CorpusService>().vocabulary,
    );
    if (_questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _finish(skipped: true),
      );
    }
  }

  static List<_Question> _buildQuestions(Level level, List<String> vocabulary) {
    final random = Random();
    return level.prelearnPairs.map((pair) {
      final correct = pair.en.toLowerCase();
      final distractors = vocabulary.where((w) => w != correct).toList()
        ..shuffle(random);
      final options = [correct, ...distractors.take(3)]..shuffle(random);
      return _Question(english: correct, russian: pair.ru, options: options);
    }).toList();
  }

  void _handleAnswer(String option) {
    if (_selected != null) return;
    final question = _questions[_currentIndex];
    setState(() {
      _selected = option;
      if (option == question.english) {
        _correctAnswers++;
      } else {
        _wrongAnswers++;
      }
    });

    Future.delayed(_feedbackDelay, () {
      if (!mounted) return;
      if (_currentIndex + 1 >= _questions.length) {
        _finish(skipped: false);
      } else {
        setState(() {
          _currentIndex++;
          _selected = null;
        });
      }
    });
  }

  void _finish({required bool skipped}) {
    if (_finished || !mounted || _level == null) return;
    _finished = true;
    Navigator.pushReplacementNamed(
      context,
      '/puzzle',
      arguments: PreLearnResult(
        level: _level!,
        correctAnswers: skipped ? 0 : _correctAnswers,
        wrongAnswers: skipped ? 0 : _wrongAnswers,
        totalQuestions: _questions.length,
        skipped: skipped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_level == null || _questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = _questions[_currentIndex];
    final progress =
        (_currentIndex + (_selected != null ? 1 : 0)) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(PreLearnScreen.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Back to menu',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              'Word ${_currentIndex + 1} of ${_questions.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
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
                question.russian,
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
                  _buildOption(option, question.english),
              ],
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _selected == null
                  ? () => _finish(skipped: true)
                  : null,
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip to puzzle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String option, String correct) {
    final answered = _selected != null;
    final isCorrect = option == correct;
    final isChosen = option == _selected;

    Color? background;
    IconData? icon;
    if (answered && isCorrect) {
      background = Colors.green;
      icon = Icons.check;
    } else if (answered && isChosen) {
      background = Colors.red;
      icon = Icons.close;
    }

    return ElevatedButton(
      onPressed: answered ? null : () => _handleAnswer(option),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: background,
        disabledBackgroundColor: background,
        disabledForegroundColor: background != null ? Colors.white : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(option, style: const TextStyle(fontSize: 18)),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
        ],
      ),
    );
  }
}

class _Question {
  final String english;
  final String russian;
  final List<String> options;

  const _Question({
    required this.english,
    required this.russian,
    required this.options,
  });
}
