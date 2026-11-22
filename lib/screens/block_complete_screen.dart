import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/corpus_service.dart';
import '../services/persistence_service.dart';
import '../services/session_block.dart';

/// Shown after the fifth solved phrase of a block: a real finish line with
/// an explicit choice of what happens next. The next block never starts
/// automatically.
class BlockCompleteScreen extends StatelessWidget {
  static const title = 'Block complete!';

  const BlockCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You have solved ${SessionBlock.blockSize} phrases '
                'in this block.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _startNextBlock(context),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Play 5 more'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.home),
                label: const Text('Back to menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNextBlock(BuildContext context) async {
    final corpus = context.read<CorpusService>();
    final profile = await context
        .read<PersistenceService>()
        .loadActiveProfile();
    if (!context.mounted) return;
    final next = profile != null
        ? corpus.getNextLevelForProfile(profile)
        : null;
    if (next == null) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    context.read<SessionBlock>().startNextBlock();
    Navigator.pushReplacementNamed(context, '/prelearn', arguments: next);
  }
}
