import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/player_profile.dart';
import '../services/corpus_service.dart';
import '../services/difficulty_service.dart';
import '../services/persistence_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  PlayerProfile? _activeProfile;
  int _totalLevels = 0;
  String? _loadError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when the player comes back from a game: refresh stats.
  @override
  void didPopNext() => _loadData();

  Future<void> _loadData() async {
    final corpusService = context.read<CorpusService>();
    final persistenceService = context.read<PersistenceService>();
    await corpusService.load();
    final profile = await persistenceService.loadActiveProfile();
    if (!mounted) return;
    setState(() {
      _activeProfile = profile;
      _totalLevels = corpusService.playableLevels.length;
      _loadError = corpusService.loadError;
      _loaded = true;
    });
  }

  Future<void> _handlePlay() async {
    final corpusService = context.read<CorpusService>();
    final persistenceService = context.read<PersistenceService>();

    var profile = await persistenceService.loadActiveProfile();
    if (profile == null) {
      if (!mounted) return;
      final name = await _askNewProfileName(firstLaunch: true);
      if (name == null) return;
      profile = await persistenceService.createProfile(name);
      await _loadData();
    }

    final nextLevel = corpusService.getNextLevelForProfile(profile);
    if (!mounted) return;
    if (nextLevel == null) {
      _showMessage(
        'No levels available',
        corpusService.loadError ?? 'The level list is empty.',
      );
      return;
    }
    Navigator.pushNamed(context, '/prelearn', arguments: nextLevel);
  }

  /// Asks for a profile name. Returns null if the dialog was dismissed.
  Future<String?> _askNewProfileName({bool firstLaunch = false}) {
    final controller = TextEditingController(
      text: firstLaunch ? PersistenceService.defaultProfileName : '',
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(firstLaunch ? 'Welcome to WORPALOX!' : 'New profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstLaunch)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('What should we call you?'),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(firstLaunch ? "Let's play" : 'Create'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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

  Future<void> _showProfileDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => _ProfileDialog(
        activeProfileId: _activeProfile?.id,
        askName: () => _askNewProfileName(),
      ),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _activeProfile?.stats;
    final recommended = stats != null
        ? DifficultyService().getRecommendedDifficulty(stats)
        : null;

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
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
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
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'English-Russian Word Puzzle',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_activeProfile != null) ...[
                      Text(
                        'Playing as: ${_activeProfile!.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (stats != null && stats.totalSolvedRuns > 0) ...[
                      _buildStatRow('Game Score', '${stats.totalGameScore}'),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Learning Progress',
                        '${stats.learningProgress}',
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Sentences Solved',
                        '${stats.uniqueSolvedLevelIds.length} / $_totalLevels',
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow('Level', recommended ?? 'easy'),
                      const SizedBox(height: 32),
                    ],
                    FilledButton.icon(
                      onPressed: _loadError == null ? _handlePlay : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play', style: TextStyle(fontSize: 18)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _loadError ?? '$_totalLevels sentences available',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _loadError != null
                            ? Colors.red
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
  final String? activeProfileId;
  final Future<String?> Function() askName;

  const _ProfileDialog({required this.activeProfileId, required this.askName});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  List<PlayerProfile> _profiles = [];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _activeId = widget.activeProfileId;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final service = context.read<PersistenceService>();
    final profiles = await service.loadProfiles();
    final active = await service.loadActiveProfile();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeId = active?.id;
    });
  }

  Future<void> _createProfile() async {
    final service = context.read<PersistenceService>();
    final name = await widget.askName();
    if (name == null) return;
    await service.createProfile(name);
    await _loadProfiles();
  }

  Future<void> _switchProfile(String id) async {
    await context.read<PersistenceService>().setActiveProfileId(id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteProfile(PlayerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('All progress of "${profile.name}" will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<PersistenceService>().deleteProfile(profile.id);
    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Player Profiles'),
      content: SizedBox(
        width: double.maxFinite,
        child: _profiles.isEmpty
            ? const Text('No profiles yet')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _profiles.length,
                itemBuilder: (ctx, index) {
                  final profile = _profiles[index];
                  final isActive = profile.id == _activeId;
                  return ListTile(
                    title: Text(profile.name),
                    subtitle: Text(
                      '${profile.stats.uniqueSolvedLevelIds.length} sentences solved',
                    ),
                    selected: isActive,
                    selectedTileColor: Colors.deepPurple[50],
                    onTap: isActive ? null : () => _switchProfile(profile.id),
                    trailing: _profiles.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProfile(profile),
                            tooltip: 'Delete profile',
                          )
                        : null,
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _createProfile,
          icon: const Icon(Icons.person_add),
          label: const Text('New'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
