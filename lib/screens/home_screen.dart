import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_profile.dart';
import '../services/corpus_service.dart';
import '../services/persistence_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlayerProfile? _activeProfile;
  int _totalLevels = 0;
  bool _loaded = false;
  String? _recommendedDifficulty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final corpusService = Provider.of<CorpusService>(context, listen: false);
    await corpusService.load();

    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    final profile = await persistenceService.loadActiveProfile();

    setState(() {
      _activeProfile = profile;
      _totalLevels = corpusService.playableLevels.length;
      _recommendedDifficulty = profile != null
          ? _getRecommendedDifficulty(profile.stats)
          : null;
      _loaded = true;
    });
  }

  String _getRecommendedDifficulty(dynamic stats) {
    final progress = stats.learningProgress;
    final totalSolved = stats.totalSolvedRuns;

    if (totalSolved < 3) {
      return 'easy';
    }

    if (progress < 100) {
      return 'easy';
    }

    final mediumCount = stats.difficultyPerformance['medium'] ?? 0;
    if (mediumCount < 5) {
      return 'medium';
    }

    return 'medium';
  }

  Future<void> _handleStartGame() async {
    final corpusService = Provider.of<CorpusService>(context, listen: false);
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    final profile = await persistenceService.loadActiveProfile();

    if (profile == null) {
      _showError('No active profile');
      return;
    }

    final nextLevel = corpusService.getNextLevelForProfile(profile);
    if (nextLevel == null) {
      _showError('No levels available');
      return;
    }

    if (mounted) {
      Navigator.pushNamed(context, '/prelearn', arguments: nextLevel);
    }
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

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ProfileDialog(
        activeProfile: _activeProfile,
        onProfileChanged: () {
          if (mounted) {
            Navigator.pop(ctx);
            _loadData();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WORPALOX'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showProfileDialog,
            tooltip: 'Profiles',
          ),
        ],
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
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'English-Russian Word Puzzle',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    if (_activeProfile != null) ...[
                      Text(
                        'Playing as: ${_activeProfile!.name}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 24),
                    if (_activeProfile != null &&
                        _activeProfile!.stats.totalSolvedRuns > 0) ...[
                      _buildStatRow(
                        'Game Score',
                        '${_activeProfile!.stats.totalGameScore}',
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Learning Progress',
                        '${_activeProfile!.stats.learningProgress}',
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Levels Solved',
                        '${_activeProfile!.stats.uniqueSolvedLevelIds.length}',
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Recommended',
                        _recommendedDifficulty ?? 'easy',
                      ),
                      const SizedBox(height: 32),
                    ],
                    ElevatedButton(
                      onPressed: _handleStartGame,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        _activeProfile != null &&
                                _activeProfile!.stats.totalSolvedRuns > 0
                            ? 'Continue'
                            : 'Start Game',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '$_totalLevels levels available',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
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
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
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

class _ProfileDialog extends StatefulWidget {
  final PlayerProfile? activeProfile;
  final VoidCallback onProfileChanged;

  const _ProfileDialog({
    required this.activeProfile,
    required this.onProfileChanged,
  });

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _nameController = TextEditingController();
  List<PlayerProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    final profiles = await persistenceService.loadProfiles();
    setState(() {
      _profiles = profiles;
    });
  }

  Future<void> _createProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    await persistenceService.createProfile(_nameController.text.trim());
    _nameController.clear();
    await _loadProfiles();
    widget.onProfileChanged();
  }

  Future<void> _switchProfile(String id) async {
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    await persistenceService.setActiveProfileId(id);
    widget.onProfileChanged();
  }

  Future<void> _deleteProfile(String id) async {
    final persistenceService = Provider.of<PersistenceService>(
      context,
      listen: false,
    );
    await persistenceService.deleteProfile(id);
    await _loadProfiles();
    widget.onProfileChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Player Profiles'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'New profile name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _createProfile,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_profiles.isEmpty)
              const Text('No profiles yet')
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: _profiles.length,
                itemBuilder: (ctx, index) {
                  final profile = _profiles[index];
                  final isActive = profile.id == widget.activeProfile?.id;
                  return ListTile(
                    title: Text(profile.name),
                    subtitle: Text(
                      '${profile.stats.totalSolvedRuns} levels solved',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isActive)
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () => _switchProfile(profile.id),
                            tooltip: 'Switch to this profile',
                          ),
                        if (_profiles.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProfile(profile.id),
                            tooltip: 'Delete profile',
                          ),
                      ],
                    ),
                    selected: isActive,
                    selectedTileColor: Colors.deepPurple[50],
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
