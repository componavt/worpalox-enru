import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worpalox/models/level.dart';
import 'package:worpalox/models/player_profile.dart';
import 'package:worpalox/models/stats.dart';
import 'package:worpalox/services/corpus_service.dart';
import 'package:worpalox/services/persistence_service.dart';

Level _lvl(int id, {String difficulty = 'easy'}) => Level(
  id: id,
  english: 'one two three four .',
  russian: 'ru',
  tokenCount: 5,
  difficulty: difficulty,
  commentaryRu: '',
  prelearnPairs: [PrelearnPair(en: 'Word$id', ru: 'r$id')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CorpusService', () {
    test('bundled levels load, are unique and playable', () async {
      final corpus = CorpusService();
      await corpus.load();
      expect(corpus.loadError, isNull);
      expect(corpus.playableLevels.length, greaterThanOrEqualTo(20));
      final texts = corpus.playableLevels.map((l) => l.english).toSet();
      expect(texts.length, corpus.playableLevels.length);
      for (final level in corpus.playableLevels) {
        expect(level.prelearnPairs, isNotEmpty, reason: 'level ${level.id}');
        expect(
          level.english.contains(" ' "),
          isFalse,
          reason: 'level ${level.id}',
        );
      }
      expect(corpus.vocabulary.length, greaterThanOrEqualTo(10));
      expect(corpus.vocabulary.every((w) => w == w.toLowerCase()), isTrue);
    });

    test('does not repeat the last level when alternatives exist', () {
      final corpus = CorpusService(random: Random(1))
        ..setLevels([_lvl(1), _lvl(2), _lvl(3)]);
      final profile = PlayerProfile(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026),
        stats: Stats(recentLevelIds: [3]),
      );
      for (var i = 0; i < 30; i++) {
        expect(corpus.getNextLevelForProfile(profile)!.id, isNot(3));
      }
    });

    test('a single available level is still returned', () {
      final corpus = CorpusService()..setLevels([_lvl(1)]);
      final profile = PlayerProfile(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026),
        stats: Stats(recentLevelIds: [1]),
      );
      expect(corpus.getNextLevelForProfile(profile)!.id, 1);
    });
  });

  group('PersistenceService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts with no profile; createProfile makes it active', () async {
      final s = PersistenceService();
      expect(await s.loadActiveProfile(), isNull);
      final a = await s.createProfile('Anna');
      final b = await s.createProfile('  ');
      expect(b.name, PersistenceService.defaultProfileName);
      expect((await s.loadActiveProfile())!.id, b.id);
      await s.setActiveProfileId(a.id);
      expect((await s.loadActiveProfile())!.name, 'Anna');
    });

    test('updateActiveProfileStats persists changes', () async {
      final s = PersistenceService();
      await s.createProfile('Anna');
      await s.updateActiveProfileStats((st) {
        st.totalGameScore += 42;
        st.addSolvedLevel(7);
      });
      final p = await s.loadActiveProfile();
      expect(p!.stats.totalGameScore, 42);
      expect(p.stats.hasSolvedLevel(7), isTrue);
    });

    test('deleting the active profile activates another one', () async {
      final s = PersistenceService();
      final a = await s.createProfile('A');
      final b = await s.createProfile('B');
      await s.deleteProfile(b.id);
      expect((await s.loadActiveProfile())!.id, a.id);
    });

    test('a corrupted save is backed up, not silently lost', () async {
      SharedPreferences.setMockInitialValues({'worpalox_save_v2': '{broken'});
      final s = PersistenceService();
      expect(await s.loadProfiles(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('worpalox_save_v2_corrupt_backup'), '{broken');
    });
  });
}
