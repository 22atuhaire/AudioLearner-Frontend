import 'package:audioapp/shared/services/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('answerNumberFromCommand', () {
    test('accepts a bare number, as a word or a digit', () {
      expect(answerNumberFromCommand('two'), 2);
      expect(answerNumberFromCommand('3'), 3);
      expect(answerNumberFromCommand('Four.'), 4);
    });

    test('accepts the number wrapped in answer words', () {
      expect(answerNumberFromCommand('answer two'), 2);
      expect(answerNumberFromCommand('option 1'), 1);
      expect(answerNumberFromCommand('my answer is option three'), 3);
      expect(answerNumberFromCommand('choose number four'), 4);
    });

    test('ignores ordinary words that merely contain a number word', () {
      // Substring matching read all of these as "one".
      expect(answerNumberFromCommand('done'), isNull);
      expect(answerNumberFromCommand('phone'), isNull);
      expect(answerNumberFromCommand('say your command after the tone'),
          isNull);
      expect(answerNumberFromCommand('someone'), isNull);
    });

    test('ignores speech that contains a number among other words', () {
      // TalkBack reading the screen while the microphone is open.
      expect(answerNumberFromCommand('Question 3 of 5'), isNull);
      expect(answerNumberFromCommand('option 2 photosynthesis button'), isNull);
      expect(answerNumberFromCommand('option 2, double tap to choose'), isNull);
    });

    test('rejects numbers beyond the options on offer', () {
      expect(answerNumberFromCommand('four', optionCount: 3), isNull);
      expect(answerNumberFromCommand('three', optionCount: 3), 3);
    });

    test('rejects empty input', () {
      expect(answerNumberFromCommand(''), isNull);
      expect(answerNumberFromCommand('answer'), isNull);
    });
  });

  group('containsPhrase', () {
    test('matches whole words and multi-word phrases', () {
      expect(containsPhrase('go to the next one', 'next'), isTrue);
      expect(containsPhrase('speed up please', 'speed up'), isTrue);
      expect(containsPhrase('Play!', 'play'), isTrue);
    });

    test('does not match inside longer words', () {
      expect(containsPhrase('display the lesson', 'play'), isFalse);
      expect(containsPhrase('upload', 'up'), isFalse);
      expect(containsPhrase('the latest news', 'test'), isFalse);
      expect(containsPhrase('bright', 'right'), isFalse);
    });

    test('containsAnyPhrase checks every phrase', () {
      expect(containsAnyPhrase('slow down', ['faster', 'slow']), isTrue);
      expect(containsAnyPhrase('downstairs', ['down']), isFalse);
    });
  });
}
