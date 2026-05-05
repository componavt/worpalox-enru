import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/corpus_service.dart';
import '../services/persistence_service.dart';
import '../models/stats.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stats _stats = Stats();
  int _totalLevels = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final corpusService = Provider.of<CorpusService>(context, listen: false);
    await corpusService.load();
    final persistenceService =
        Provider.of<PersistenceService>(context, listen: false);
    _stats = await persistenceService.loadStats();
    setState(() {
      _totalLevels = corpusService.playableLevels.length;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WORPALOX'),
        centerTitle: true,
      ),
      body: _loaded
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.school,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'WORPALOX',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'English-Russian Word Puzzle',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 48),
                    if (_stats.totalSolved > 0) ...[
                      _buildStatRow('Levels Solved', '${_stats.totalSolved}'),
                      const SizedBox(height: 8),
                      _buildStatRow(
                          'Avg Swaps', '${_stats.averageSwaps.toStringAsFixed(1)}'),
                      const SizedBox(height: 8),
                      _buildStatRow(
                          'Avg Checks', '${_stats.averageChecks.toStringAsFixed(1)}'),
                      const SizedBox(height: 32),
                    ],
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/prelearn');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '$_totalLevels short levels available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ],
    );
  }
}
