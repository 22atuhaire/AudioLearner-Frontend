/// Pure helpers for turning a recognised phrase into a learning-hub command.
///
/// Kept free of Flutter and of the hub's state so the matching rules can be
/// unit-tested. They matter more than they look: the microphone can hear the
/// app's own speech and TalkBack's speech, so every rule here has to separate
/// "the student said this" from "this word happened to be in the room".
library;

final RegExp _nonWord = RegExp(r'[^a-z0-9]+');

/// Lower-cases [text] and reduces it to single-space-separated words, so
/// matching ignores punctuation the recognizer may or may not include.
String normalizeCommand(String text) =>
    text.toLowerCase().replaceAll(_nonWord, ' ').trim();

/// True when [phrase] occurs in [command] as whole words.
///
/// Substring matching made ordinary words fire commands: "done", "phone" and
/// "tone" all contain "one" (answer one), "display" contains "play" and
/// "upload" contains "up".
bool containsPhrase(String command, String phrase) {
  final c = ' ${normalizeCommand(command)} ';
  final p = normalizeCommand(phrase);
  if (p.isEmpty) return false;
  return c.contains(' $p ');
}

/// True when any of [phrases] occurs in [command] as whole words.
bool containsAnyPhrase(String command, Iterable<String> phrases) =>
    phrases.any((p) => containsPhrase(command, p));

const Map<String, int> _numberWords = {
  '1': 1,
  'one': 1,
  'won': 1,
  'first': 1,
  '2': 2,
  'two': 2,
  'second': 2,
  '3': 3,
  'three': 3,
  'third': 3,
  '4': 4,
  'four': 4,
  'fourth': 4,
};

/// Words a student may wrap around an answer number ("my answer is two",
/// "choose option three") that carry no meaning of their own.
const Set<String> _answerFiller = {
  'i',
  'my',
  'the',
  'is',
  'it',
  'its',
  's',
  'answer',
  'option',
  'number',
  'choice',
  'choose',
  'pick',
  'select',
};

/// Extracts a quiz answer number (1..[optionCount]) from a spoken phrase, or
/// null when the phrase is not clearly an answer.
///
/// After removing filler words the phrase must be exactly one number. That
/// accepts "two", "answer two" and "my answer is option 2", and rejects
/// anything that merely contains a number: "question 3 of 5", or TalkBack
/// reading "Option 2: photosynthesis, button" while the microphone is open.
/// Choosing an answer submits it, so a false match here is a wrong answer the
/// student never gave.
int? answerNumberFromCommand(String command, {int optionCount = 4}) {
  final words = normalizeCommand(command)
      .split(' ')
      .where((w) => w.isNotEmpty && !_answerFiller.contains(w))
      .toList();
  if (words.length != 1) return null;
  final n = _numberWords[words.single];
  if (n == null || n < 1 || n > optionCount) return null;
  return n;
}
