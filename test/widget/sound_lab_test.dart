import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:worpalox/screens/sound_lab_puzzle_screen.dart';
import 'package:worpalox/services/placement_sound.dart';
import 'package:worpalox/widgets/word_token.dart';

/// Records gameplay sound requests instead of playing anything.
class FakePlacementAudio implements PlacementAudio {
  int playCalls = 0;
  @override
  String selectedId = offSoundId;

  @override
  Future<void> select(String id) async {
    selectedId = id;
  }

  @override
  Future<void> preview(PlacementSound sound) async {}

  @override
  Future<void> stopPreview() async {}

  @override
  Future<void> playCorrectPlacement() async {
    playCalls++;
  }
}

/// One correct placement: move "The" (third chip) to the front by tapping
/// it and then tapping the destination chip.
Future<void> _makeCorrectMove(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(WordToken, 'The'));
  await tester.pump();
  await tester.tap(find.widgetWithText(WordToken, 'flew'));
  await tester.pumpAndSettle();
}

Future<void> _makeWrongMove(WidgetTester tester) async {
  // Moving doors onto The is wrong for this fixed start and never places
  // a chip correctly.
  await tester.tap(find.widgetWithText(WordToken, 'doors'));
  await tester.pump();
  await tester.tap(find.widgetWithText(WordToken, 'The'));
  await tester.pumpAndSettle();
}

Widget _wrap(PlacementAudio audio) => MaterialApp(
  home: Provider<PlacementAudio>.value(
    value: audio,
    child: const SoundLabPuzzleScreen(),
  ),
);

void main() {
  testWidgets('one correct placement triggers exactly one sound call', (
    tester,
  ) async {
    final fake = FakePlacementAudio();
    await fake.select('drop_001');
    await tester.pumpWidget(_wrap(fake));

    await _makeCorrectMove(tester);
    expect(fake.playCalls, 1);
  });

  testWidgets('wrong placement triggers no sound calls', (tester) async {
    final fake = FakePlacementAudio();
    await fake.select('drop_001');
    await tester.pumpWidget(_wrap(fake));

    await _makeWrongMove(tester);
    expect(fake.playCalls, 0);
  });

  testWidgets('Off never emits a sound (real service gate)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = SoundService();
    await service.loadPreference();
    var emitted = 0;
    service.onEmit = (_, _) => emitted++;
    await tester.pumpWidget(_wrap(service));

    // The default choice is Off.
    expect(service.selectedId, offSoundId);
    await _makeCorrectMove(tester);
    expect(emitted, 0);
  });

  testWidgets('real service emits one sound per correct placement', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = SoundService();
    await service.loadPreference();
    var emitted = 0;
    service.onEmit = (_, _) => emitted++;
    await tester.pumpWidget(_wrap(service));

    await service.select('drop_001');
    expect(service.selectedId, 'drop_001');
    await _makeCorrectMove(tester);
    expect(emitted, 1);
  });

  testWidgets('Reset allows celebrating the same chip again', (tester) async {
    final fake = FakePlacementAudio();
    await fake.select('drop_001');
    await tester.pumpWidget(_wrap(fake));

    await _makeCorrectMove(tester);
    await tester.tap(find.text('Reset test puzzle'));
    await tester.pumpAndSettle();
    await _makeCorrectMove(tester);
    expect(fake.playCalls, 2);
  });
}
