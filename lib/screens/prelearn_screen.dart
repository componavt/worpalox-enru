import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/level.dart';
import '../services/corpus_service.dart';
import '../services/persistence_service.dart';

class PreLearnScreen extends StatefulWidget {
  const PreLearnScreen({super.key});

  @override
  State<PreLearnScreen> createState() => _PreLearnScreenState();
}

class _PreLearnScreenState extends State<PreLearnScreen> {
  Level? _currentLevel;
  int _currentIndex = 0;
  List<_WordPair> _pairs = [];
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    final corpusService = Provider.of<CorpusService>(context, listen: false);
    final persistenceService =
        Provider.of<PersistenceService>(context, listen: false);
    final lastId = await persistenceService.getLastPlayedLevelId();
    final nextLevel = corpusService.getNextLevel(lastId);

    if (nextLevel == null) {
      _showError('No levels available');
      return;
    }

    setState(() {
      _currentLevel = nextLevel;
      _preparePairs(nextLevel);
    });
  }

  void _preparePairs(Level level) {
    final tokens = level.english.split(' ');
    final russianTokens = level.russian.split(' ');

    final indices = [0, tokens.length ~/ 2].where((i) => i < tokens.length).toList();
    _pairs = indices.map((i) => _WordPair(
      en: tokens[i],
      ru: i < russianTokens.length ? russianTokens[i] : '?',
    )).toList();
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

  @override
  Widget build(BuildContext context) {
    if (_currentLevel == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(
          context,
          '/puzzle',
          arguments: _currentLevel,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentIndex >= _pairs.length) {
      setState(() => _completed = true);
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pair = _pairs[_currentIndex];
    final progress = (_currentIndex + 1) / _pairs.length;

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
              'Find the English word:',
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
                pair.ru,
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
                _buildOption(pair.en, correct: true),
                _buildOption(_shuffleToken(pair.en), correct: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String text, {required bool correct}) {
    return ElevatedButton(
      onPressed: () {
        setState(() => _currentIndex++);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  String _shuffleToken(String avoid) {
    final tokens = _currentLevel!.english.split(' ').where((t) => t != avoid).toList();
    if (tokens.isEmpty) return avoid;
    return tokens.first;
  }
}

class _WordPair {
  final String en;
  final String ru;
  _WordPair({required this.en, required this.ru});
}
