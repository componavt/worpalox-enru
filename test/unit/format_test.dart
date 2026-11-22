import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/screens/puzzle_screen.dart';

void main() {
  test('formatResultSentence glues a separated terminal mark', () {
    expect(formatResultSentence('The doors flew open .'),
        'The doors flew open.');
    expect(formatResultSentence('Двери распахнулись .'),
        'Двери распахнулись.');
    expect(formatResultSentence('Здесь есть , однако , одно обстоятельство ...'),
        'Здесь есть , однако , одно обстоятельство...');
  });

  test('formatResultSentence keeps already glued marks and inner punctuation',
      () {
    expect(formatResultSentence('Двери распахнулись.'), 'Двери распахнулись.');
    expect(formatResultSentence('I was sent for at eight o ’ clock on the 17th .'),
        'I was sent for at eight o ’ clock on the 17th.');
    // Inner punctuation is display-untouched: only the terminal mark moves.
    expect(formatResultSentence('Wait , one , two , three !'),
        'Wait , one , two , three!');
  });

  test('formatResultSentence trims trailing whitespace', () {
    expect(formatResultSentence('The doors flew open .  '), 'The doors flew open.');
  });
}
