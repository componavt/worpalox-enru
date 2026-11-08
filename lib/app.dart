import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/prelearn_screen.dart';
import 'screens/puzzle_screen.dart';
import 'services/corpus_service.dart';
import 'services/persistence_service.dart';
import 'services/scoring_service.dart';

/// Lets the home screen refresh its stats when the player returns to it.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class WorpaloxApp extends StatelessWidget {
  final CorpusService? corpusService;
  final PersistenceService? persistenceService;

  const WorpaloxApp({super.key, this.corpusService, this.persistenceService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => corpusService ?? CorpusService()),
        Provider(create: (_) => persistenceService ?? PersistenceService()),
        Provider(create: (_) => ScoringService()),
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
        },
      ),
    );
  }
}
