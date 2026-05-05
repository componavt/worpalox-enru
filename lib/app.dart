import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/prelearn_screen.dart';
import 'screens/puzzle_screen.dart';
import 'services/corpus_service.dart';
import 'services/persistence_service.dart';
import 'services/scoring_service.dart';

class WorpaloxApp extends StatelessWidget {
  const WorpaloxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => CorpusService()),
        Provider(create: (_) => PersistenceService()),
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
