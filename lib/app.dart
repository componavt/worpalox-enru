import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/block_complete_screen.dart';
import 'screens/home_screen.dart';
import 'screens/prelearn_screen.dart';
import 'screens/puzzle_screen.dart';
import 'screens/scene_complete_screen.dart';
import 'screens/sound_lab_puzzle_screen.dart';
import 'screens/sound_lab_screen.dart';
import 'screens/story_screen.dart';
import 'services/corpus_service.dart';
import 'services/persistence_service.dart';
import 'services/placement_sound.dart';
import 'services/scoring_service.dart';
import 'services/session_block.dart';

/// Lets the home screen refresh its stats when the player returns to it.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class WorpaloxApp extends StatelessWidget {
  final CorpusService? corpusService;
  final PersistenceService? persistenceService;
  final SessionBlock? sessionBlock;
  final PlacementAudio? placementAudio;

  const WorpaloxApp({
    super.key,
    this.corpusService,
    this.persistenceService,
    this.sessionBlock,
    this.placementAudio,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => corpusService ?? CorpusService()),
        Provider(create: (_) => persistenceService ?? PersistenceService()),
        Provider(create: (_) => ScoringService()),
        ChangeNotifierProvider<SessionBlock>(
          create: (_) => sessionBlock ?? SessionBlock(),
        ),
        Provider<PlacementAudio>(
          create: (_) {
            final service = placementAudio ?? SoundService();
            if (service is SoundService) service.loadPreference();
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'WORPALOX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
        navigatorObservers: [routeObserver],
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/prelearn': (context) => const PreLearnScreen(),
          '/puzzle': (context) => const PuzzleScreen(),
          '/blockComplete': (context) => const BlockCompleteScreen(),
          '/story': (context) => const StoryScreen(),
          '/sceneComplete': (context) => const SceneCompleteScreen(
            titleRu: 'Сцена завершена',
          ),
          '/soundLab': (context) => const SoundLabScreen(),
          '/soundLabPuzzle': (context) => const SoundLabPuzzleScreen(),
        },
      ),
    );
  }
}
