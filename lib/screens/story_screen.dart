import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/level.dart';
import '../models/route_arguments.dart';
import '../models/story_scene.dart';
import '../services/corpus_service.dart';

/// Shows the editorial context of a scene and starts its puzzle chain.
/// Context text is never a playable level and never enters the random pool.
class StoryScreen extends StatefulWidget {
  final StoryScene? scene; // injected for tests; the default asset when null

  const StoryScreen({super.key, this.scene});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  static const assetPath = 'assets/scenes/rocket_summer_01.json';

  StoryScene? _scene;
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    if (widget.scene != null) {
      _scene = widget.scene;
    } else {
      _loadScene();
    }
  }

  Future<void> _loadScene() async {
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      if (!mounted) return;
      setState(() => _scene = StoryScene.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load the scene: $e');
    }
  }

  void _startScene() {
    // One start at a time: the Home lock does not cover this screen.
    if (_starting) return;
    final scene = _scene!;
    if (scene.puzzleSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This scene has no puzzles yet')),
      );
      return;
    }
    final corpus = context.read<CorpusService>();
    final levels = <Level>[];
    for (final step in scene.puzzleSteps) {
      // Story-only levels stay addressable by id even though they never
      // enter the random Play pool.
      final level = corpus.levelById(step.levelId ?? -1);
      if (level == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Level ${step.levelId} is not available')),
        );
        return;
      }
      levels.add(level);
    }
    _starting = true;
    Navigator.pushReplacementNamed(
      context,
      '/puzzle',
      arguments: SceneRun(scene: scene, levels: levels, index: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Story')),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }
    if (scene == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final puzzleCount = scene.puzzleSteps.length;
    return Scaffold(
      appBar: AppBar(title: Text(scene.titleRu)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final step in scene.contextSteps) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  step.textRu ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startScene,
              icon: const Icon(Icons.arrow_forward),
              label: Text('Начать фразу 1 из $puzzleCount'),
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
    );
  }
}
