import 'package:flutter/material.dart';

/// Shown when every puzzle step of a scene is solved.
class SceneCompleteScreen extends StatelessWidget {
  final String titleRu;

  const SceneCompleteScreen({super.key, required this.titleRu});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titleRu)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_stories, size: 72, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text(
                'Scene complete!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Вы собрали всю сцену — от предыстории до финала.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
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
}
