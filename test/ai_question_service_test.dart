import 'package:audioapp/shared/services/ai_question_service.dart';
import 'package:audioapp/shared/services/question_answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for [AiQuestionService] — the offline, deterministic quiz
/// generator. Pure Dart (no network, no ML model, no platform channels).
void main() {
  late AiQuestionService service;

  setUp(() => service = AiQuestionService());

  test('returns no questions for blank text', () {
    expect(service.generateQuestions(''), isEmpty);
    expect(service.generateQuestions('   '), isEmpty);
  });

  test('returns no questions when there are too few usable sentences', () {
    // Fewer than four sentences → cannot build three distinct wrong answers.
    expect(service.generateQuestions('The sky is blue today.'), isEmpty);
  });

  group('with a multi-sentence lesson', () {
    // Needs at least four sentences, each with >= 8 words, to generate.
    const lesson =
        'Photosynthesis is the process by which green plants make their own food. '
        'Chlorophyll is the green pigment that captures light energy from the sun. '
        'Oxygen is the gas that plants release back into the surrounding air. '
        'Glucose is the sugar that plants produce and store for later energy. '
        'Carbon dioxide is the gas that plants absorb through tiny leaf pores.';

    test('generates at least one question', () {
      expect(service.generateQuestions(lesson), isNotEmpty);
    });

    test('every question has four non-empty options and a valid answer key',
        () {
      for (final q in service.generateQuestions(lesson)) {
        expect(q.questionText.trim(), isNotEmpty);
        expect(q.optionA.trim(), isNotEmpty);
        expect(q.optionB.trim(), isNotEmpty);
        expect(q.optionC.trim(), isNotEmpty);
        expect(q.optionD.trim(), isNotEmpty);
        expect(const ['A', 'B', 'C', 'D'], contains(q.correctOption));
      }
    });

    test('is deterministic — same text yields the same questions', () {
      final first = service.generateQuestions(lesson);
      final second = service.generateQuestions(lesson);
      expect(first.length, second.length);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].questionText, second[i].questionText);
        expect(first[i].correctOption, second[i].correctOption);
      }
    });
  });

  // Regression tests from a real P.6 mathematics note that produced
  // "What is Since 6?", "What are Key terms: Addends?", and options cut off
  // mid-parenthesis ("…is even (0"). Structured notes — label lines, worked
  // examples, rule lists — must never leak structure into questions.
  group('with a structured real-world note', () {
    const note = '''
MATHEMATICS NOTES FOR PRIMARY SIX (P.6)

1. PLACE VALUE

The place value is the position of a digit in a number (like Ones, Tens, Hundreds, Thousands).

Example: In the number 4,567,890, the digit 5 is in the Hundred Thousands place, so its total value is 500,000.

Rules for rounding:
Look at the digit to the right of the place you are rounding to.
If that digit is 5 or more, round up.
Since 6 is 5 or more, round up. 89,365 becomes 89,400.

Key terms:
Addends are the numbers being added. The answer is the sum.
In subtraction, the number being subtracted from is the minuend, the number subtracted is the subtrahend, and the answer is the difference.

Rules for divisibility:
A number is divisible by 2 if its last digit is even (0, 2, 4, 6, 8).
A number is divisible by 3 if the sum of its digits is divisible by 3.
A number is divisible by 5 if its last digit is 0 or 5.

Following BODMAS, addition and subtraction are done from left to right.
''';

    late List<AiGeneratedQuestion> questions;

    setUp(() => questions = AiQuestionService().generateQuestions(note));

    test('generates questions from the note', () {
      expect(questions, isNotEmpty);
    });

    test('never builds a subject from a subordinate clause or fused label', () {
      for (final q in questions) {
        // "What is Since 6?" / "What are Following BODMAS…?"
        expect(q.questionText, isNot(contains('Since')));
        expect(q.questionText, isNot(contains('Following')));
        // "What is Rules for divisibility: A number?" — label fused on.
        expect(q.questionText, isNot(contains(':')));
        expect(q.questionText, isNot(contains('Key terms')));
      }
    });

    test('conditional rules are never presented as definitions', () {
      for (final q in questions) {
        // "A number is divisible by 2 IF…" is a rule, not what a number IS.
        expect(
            q.questionText.toLowerCase(), isNot(contains('what is a number')));
      }
    });

    test('options are clean spoken phrases', () {
      for (final q in questions) {
        for (final opt in [q.optionA, q.optionB, q.optionC, q.optionD]) {
          // No dangling parenthesis ("…is even (0").
          final opens = '('.allMatches(opt).length;
          final closes = ')'.allMatches(opt).length;
          expect(opens, closes,
              reason: 'unbalanced parentheses in option "$opt"');
          // No leftover comma fragments ("2, so yes").
          expect(opt.trim(), isNot(endsWith(',')));
          expect(opt.trim(), isNot(startsWith(',')));
        }
      }
    });

    test('the Addends definition is extracted correctly', () {
      final addends = questions
          .where((q) => q.questionText.toLowerCase().contains('addends'));
      for (final q in addends) {
        expect(q.questionText.toLowerCase(), 'what are addends?');
      }
    });

    test('headings never become questions', () {
      for (final q in questions) {
        expect(q.questionText, isNot(contains('MATHEMATICS')));
        expect(q.questionText, isNot(contains('PLACE VALUE AND')));
      }
    });
  });

  // Regression for the defect the evaluation harness (eval/) exposed: the
  // generator walked sentences in reading order and stopped at five, so a
  // multi-section note got five questions about its FIRST section and nothing
  // about the rest. Measured recall was 42%; spreading selection across
  // sections raised it to ~68%.
  group('coverage spread across a multi-section note', () {
    const note = '''
ENGLISH NOTES FOR PRIMARY SIX

2. NOUNS

A noun is a word that names a person, a place, an animal or a thing.
A common noun is a noun that names any one of a group of things.
A proper noun is a noun that names a particular person or place.
A collective noun is a noun that names a group of things taken together.

3. PRONOUNS

A pronoun is a word that is used in place of a noun.

4. VERBS

A verb is a word that shows an action or a state of being.

5. ADJECTIVES

An adjective is a word that describes a noun or a pronoun.

6. ADVERBS

An adverb is a word that describes a verb or an adjective.

7. PREPOSITIONS

A preposition is a word that shows the position of a noun.
''';

    late List<AiGeneratedQuestion> questions;
    setUp(() => questions = AiQuestionService().generateQuestions(note));

    test('does not spend every question on the first section', () {
      final aboutNounTypes = questions
          .where((q) =>
              q.questionText.toLowerCase().contains('common noun') ||
              q.questionText.toLowerCase().contains('proper noun') ||
              q.questionText.toLowerCase().contains('collective noun'))
          .length;
      expect(aboutNounTypes, lessThan(3),
          reason: 'quiz is clustered on one section again');
    });

    test('reaches later sections of the note', () {
      final joined =
          questions.map((q) => q.questionText.toLowerCase()).join(' | ');
      final laterTopics = [
        'pronoun',
        'verb',
        'adjective',
        'adverb',
        'preposition'
      ].where(joined.contains).length;
      expect(laterTopics, greaterThanOrEqualTo(3),
          reason: 'later sections were never reached: $joined');
    });

    test('asks about distinct topics rather than repeating one', () {
      final heads = questions
          .map((q) => q.questionText.toLowerCase())
          .map((t) =>
              t.replaceAll(RegExp(r'^what (is|are) |^when (is|are) '), ''))
          .toSet();
      expect(heads.length, questions.length,
          reason: 'duplicate question subjects: $heads');
    });
  });

  group('lesson question retrieval', () {
    const lesson =
        'Reproduction is the process by which living things produce new organisms. '
        'Asexual reproduction involves only one parent and produces offspring that are genetically similar. '
        'Sexual reproduction usually involves two parents.';

    test('prefers a direct definition for what-is questions', () {
      final answer = QuestionAnswerService().answer(
        'What is reproduction?',
        lesson,
      );

      expect(
          answer,
          startsWith(
              'Reproduction is the process by which living things produce new organisms.'));
      expect(answer, isNot(startsWith('Asexual reproduction')));
    });
  });

  group('teachable question wording', () {
    test('keeps the complete definition answer', () {
      const note = '''
The digestive system is the group of organs that work together to digest food.
The alimentary canal is the long tube that runs from the mouth to the anus.
Hydrochloric acid is the acid in the stomach that kills germs found in food.
Peristalsis is the wave-like movement of muscles that pushes food along the gut.
Constipation is a condition where a person fails to pass out faeces easily.
''';

      final questions = service.generateQuestions(note);
      final digestive = questions.firstWhere(
        (q) => q.questionText.toLowerCase() == 'what is the digestive system?',
      );
      expect(
        [
          digestive.optionA,
          digestive.optionB,
          digestive.optionC,
          digestive.optionD,
        ][const ['A', 'B', 'C', 'D'].indexOf(digestive.correctOption)],
        'the group of organs that work together to digest food',
      );
    });

    test('uses informative identification questions for named features', () {
      const note = '''
Mount Rwenzori is the highest mountain in Uganda and it is found in the west.
Mount Elgon is an extinct volcano that is found in the east of Uganda.
Mount Moroto is a mountain found in the north east of Uganda in Karamoja.
Lake Victoria is the largest lake in Uganda and in the whole of Africa.
Lake Albert is a rift valley lake found in the western part of Uganda.
''';

      final questions = service.generateQuestions(note);
      expect(
        questions.any(
            (q) => q.questionText.toLowerCase().contains('highest mountain')),
        isTrue,
      );
      expect(
        questions.any(
            (q) => q.questionText.toLowerCase().contains('extinct volcano')),
        isTrue,
      );
      expect(
        questions
            .any((q) => q.questionText.toLowerCase().contains('largest lake')),
        isTrue,
      );
    });

    test('turns explain-why activities into causal questions', () {
      const note = '''
Altitude is the height of a place above sea level.
Places at a high altitude such as Kabale are colder than places at a low altitude.
Explain why Kabale is colder than Kampala.
Rainfall is the amount of water that falls from the clouds onto the ground.
Temperature is the degree of hotness or coldness of a place.
''';

      final questions = service.generateQuestions(note);
      final question = questions.firstWhere(
        (q) => q.questionText.toLowerCase().startsWith('explain why kabale'),
      );
      expect(
          question.questionText, 'Explain why Kabale is colder than Kampala?');
      expect(question.explanation, contains('high altitude'));
    });
  });
}
