import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/services/hint_service.dart';

void main() {
  group('HintService', () {
    final hintService = HintService();

    test('returns correct hints for matching positions', () {
      final current = ['A', 'B', 'C'];
      final correct = ['A', 'B', 'C'];
      
      final hints = hintService.getHints(current, correct);
      
      expect(hints, equals([HintStatus.correct, HintStatus.correct, HintStatus.correct]));
    });

    test('returns wrong hints for mismatched positions', () {
      final current = ['C', 'B', 'A'];
      final correct = ['A', 'B', 'C'];
      
      final hints = hintService.getHints(current, correct);
      
      expect(hints[0], equals(HintStatus.wrong)); 
      expect(hints[1], equals(HintStatus.correct)); 
      expect(hints[2], equals(HintStatus.wrong)); 
    });

    test('returns all wrong for length mismatch', () {
      final current = ['A', 'B'];
      final correct = ['A', 'B', 'C'];
      
      final hints = hintService.getHints(current, correct);
      
      expect(hints, equals([HintStatus.wrong, HintStatus.wrong]));
    });

    test('getHintBooleans returns correct boolean list', () {
      final current = ['A', 'C', 'B'];
      final correct = ['A', 'B', 'C'];
      
      final booleans = hintService.getHintBooleans(current, correct);
      
      expect(booleans, equals([true, false, false]));
    });
  });
}
