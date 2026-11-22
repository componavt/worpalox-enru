import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/level.dart';
import '../services/placement_sound.dart';

/// Test-only sound laboratory: compare the Kenney CC0 candidates, pick the
/// gameplay sound and try it in a fixed puzzle. Removed from release builds
/// once the winner is chosen.
class SoundLabScreen extends StatefulWidget {
  const SoundLabScreen({super.key});

  @override
  State<SoundLabScreen> createState() => _SoundLabScreenState();
}

class _SoundLabScreenState extends State<SoundLabScreen> {
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<PlacementAudio>();
    var currentLabel = 'Off';
    for (final sound in placementSounds) {
      if (sound.id == audio.selectedId) currentLabel = sound.label;
    }
    if (audio.selectedId == offSoundId) currentLabel = 'Off';

    return Scaffold(
      appBar: AppBar(title: const Text('Sound Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Current: $currentLabel',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap play to preview; tap a row to assign it to the game.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          for (final sound in placementSounds)
            ListTile(
              title: Text(sound.label),
              selected: audio.selectedId == sound.id,
              leading: IconButton(
                tooltip: 'Preview ${sound.label}',
                icon: const Icon(Icons.play_arrow),
                onPressed: () => audio.preview(sound),
              ),
              trailing: audio.selectedId == sound.id
                  ? const Icon(Icons.check)
                  : const Icon(Icons.circle_outlined),
              onTap: () => audio
                .select(sound.id)
                .then((_) => mounted ? setState(() {}) : null),
            ),
          const Divider(),
          ListTile(
            title: const Text('Off'),
            selected: audio.selectedId == offSoundId,
            trailing: audio.selectedId == offSoundId
                ? const Icon(Icons.check)
                : const Icon(Icons.circle_outlined),
            onTap: () => audio
                .select(offSoundId)
                .then((_) => mounted ? setState(() {}) : null),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/soundLabPuzzle'),
            icon: const Icon(Icons.extension),
            label: const Text('Try in puzzle'),
          ),
          const SizedBox(height: 8),
          Text(
            'The test puzzle starts from a fixed order and never saves '
            'scores or progress.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Level soundLabLevel() => const Level(
  id: 901, // display-only: the lab puzzle never saves scores or progress
  english: 'The doors flew open .',
  russian: 'Двери распахнулись .',
  tokenCount: 5,
  difficulty: 'easy',
  commentaryRu: '',
  prelearnPairs: [],
);
