import 'dart:async';

import 'package:audioapp/features/student/student_learning_hub_screen.dart';
import 'package:audioapp/shared/services/db/app_database.dart';
import 'package:audioapp/shared/services/providers.dart';
import 'package:audioapp/shared/services/stt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Drives the real learning hub the way TalkBack does — through semantics
// actions — and checks where accessibility focus is sent, what is spoken by
// whom, and when the microphone opens. Speech plugins are faked at their
// method channels; nothing here needs a device.

const _subject = Subject(id: 1, teacherId: 1, name: 'Science', createdAt: 0);
const _topic =
    Topic(id: 1, subjectId: 1, name: 'Plants', orderIndex: 0, createdAt: 0);
const _lesson = Lesson(
  id: 1,
  topicId: 1,
  rawText: 'Plants make their food from sunlight. This is photosynthesis.',
  createdAt: 0,
);
const _questions = [
  Question(
    id: 1,
    lessonId: 1,
    questionText: 'What do plants need to make food?',
    optionA: 'Sunlight',
    optionB: 'Sand',
    optionC: 'Salt',
    optionD: 'Smoke',
    correctOption: 'A',
    explanation: '',
    positionInLesson: 0,
    source: 'test',
  ),
  Question(
    id: 2,
    lessonId: 1,
    questionText: 'What is this process called?',
    optionA: 'Digestion',
    optionB: 'Photosynthesis',
    optionC: 'Breathing',
    optionD: null,
    correctOption: 'B',
    explanation: '',
    positionInLesson: 1,
    source: 'test',
  ),
];

class _FakePlatforms {
  final tts = <String>[];
  final spoken = <String>[];
  final stt = <String>[];
  final a11y = <Map<Object?, Object?>>[];

  /// When set, `speak` stays pending until the test completes it — a prompt
  /// that is still being spoken.
  Completer<int>? holdSpeech;

  void install(TestDefaultBinaryMessenger messenger) {
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call) async {
      tts.add(call.method);
      switch (call.method) {
        case 'getLanguages':
          return ['en-US'];
        case 'speak':
          // Android sends {text, focus}; other platforms send the text.
          final args = call.arguments;
          spoken.add(args is Map ? args['text'] as String : args as String);
          return holdSpeech?.future ?? 1;
        case 'stop':
          final held = holdSpeech;
          if (held != null && !held.isCompleted) held.complete(0);
          return 1;
        default:
          return 1;
      }
    });
    const sttName = 'plugin.csdcorp.com/speech_to_text';
    messenger.setMockMethodCallHandler(const MethodChannel(sttName),
        (call) async {
      stt.add(call.method);
      if (call.method == 'listen') {
        await messenger.handlePlatformMessage(
          sttName,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('notifyStatus', 'listening')),
          (_) {},
        );
      }
      return true;
    });
    messenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility,
        (message) async {
      a11y.add(message! as Map<Object?, Object?>);
      return null;
    });
  }

  /// The recognizer reports an engine error, as Android does.
  /// In the order Android delivers it: statuses first, then the error.
  Future<void> recognizerError(
      TestDefaultBinaryMessenger messenger, String error) async {
    Future<void> send(MethodCall call) => messenger.handlePlatformMessage(
          'plugin.csdcorp.com/speech_to_text',
          const StandardMethodCodec().encodeMethodCall(call),
          (_) {},
        );
    await send(const MethodCall('notifyStatus', 'notListening'));
    await send(const MethodCall('notifyStatus', 'doneNoResult'));
    await send(MethodCall(
        'notifyError', '{"errorMsg":"$error","permanent":true}'));
  }

  int get listens => stt.where((m) => m == 'listen').length;

  bool focusSentTo(SemanticsNode node) =>
      a11y.any((m) => m['type'] == 'focus' && m['nodeId'] == node.id);

  Iterable<String> get announcements => a11y
      .where((m) => m['type'] == 'announce')
      .map((m) => (m['data']! as Map)['message'] as String);
}

// The speech plugin is a process-wide singleton bound to the first service
// that initialises it, exactly as the app has one long-lived SttService.
final _stt = SttService();

Widget _app() => ProviderScope(
      overrides: [
        sttServiceProvider.overrideWithValue(_stt),
        allSubjectsProvider.overrideWith((ref) async => [_subject]),
        subjectTopicsProvider.overrideWith((ref, id) async => [_topic]),
        topicLessonProvider.overrideWith((ref, id) async => _lesson),
        lessonQuestionsProvider.overrideWith((ref, id) async => _questions),
        // No database in these tests; the hub's progress and cloud-sync
        // writes already tolerate failure.
        appDatabaseProvider.overrideWith(
            (ref) => throw UnsupportedError('no database in tests')),
      ],
      child: const MaterialApp(home: StudentLearningHubScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakePlatforms platforms;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platforms = _FakePlatforms()
      ..install(
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  group('with TalkBack on', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
    });
    tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue());

    testWidgets(
        'focus follows each new screen and question; focusing an answer does '
        'not choose it; the app never speaks over TalkBack or opens the mic',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await settle(tester);

      // Landing: focus goes to the subject card.
      final subjectCard = find.semantics.byLabel('Science. Subject 1 of 1.');
      expect(platforms.focusSentTo(subjectCard.evaluate().single), isTrue);

      // Open the subject, then the topic: focus moves to each new card
      // instead of being left on a control that no longer exists.
      tester.semantics.tap(subjectCard);
      await settle(tester);
      final topicCard =
          find.semantics.byLabel('Plants. Topic 1 of 1 in Science.');
      expect(platforms.focusSentTo(topicCard.evaluate().single), isTrue);

      tester.semantics.tap(topicCard);
      await settle(tester);
      final lessonCard = find.semantics.byLabel('Plants lesson. Ready to play.');
      expect(platforms.focusSentTo(lessonCard.evaluate().single), isTrue);
      // The card must not read lesson text — that sounded like the lesson
      // playing while the app said it was not.
      expect(find.semantics.byLabel(RegExp('sunlight')), findsNothing);

      tester.semantics.tap(find.semantics.byLabel('Go to questions'));
      await settle(tester);
      tester.semantics
          .tap(find.semantics.byLabel('Questions for Plants. Ready to start.'));
      await settle(tester);

      final firstQuestion = find.semantics
          .byLabel('Question 1 of 2. What do plants need to make food?');
      expect(platforms.focusSentTo(firstQuestion.evaluate().single), isTrue);

      // Exploring answers with TalkBack moves its focus, and nothing else.
      final optionTwo = find.semantics.byLabel('Option 2: Sand');
      tester.semantics.performAction(
          optionTwo, SemanticsAction.didGainAccessibilityFocus,
          checkForAction: false);
      await settle(tester);
      expect(find.semantics.byLabel('Option 1: Sunlight'), findsOne);
      expect(find.semantics.byLabel(RegExp('^You chose')), findsNothing);
      // No answer is drawn as chosen before the student chooses.
      expect(find.semantics.byLabel('Next question'), findsNothing);

      // Double tap (activation) chooses; focus moves to the result.
      tester.semantics.tap(optionTwo);
      await settle(tester);
      final feedback = find.semantics.byLabel(
          RegExp(r'^You chose option 2\. Incorrect\. The correct answer is '
              r'option 1\. Sunlight\.'));
      expect(platforms.focusSentTo(feedback.evaluate().single), isTrue);

      // Next question: focus goes to the new question, not the top of the
      // screen.
      platforms.a11y.clear();
      tester.semantics.tap(find.semantics.byLabel('Next question'));
      await settle(tester);
      final secondQuestion = find.semantics
          .byLabel('Question 2 of 2. What is this process called?');
      expect(platforms.focusSentTo(secondQuestion.evaluate().single), isTrue);
      // ...and it is read once, by TalkBack from focus — not announced too.
      expect(platforms.announcements, isEmpty);

      // The only speech was TalkBack's; the microphone never opened.
      expect(platforms.tts, isNot(contains('speak')));
      expect(platforms.stt, isNot(contains('listen')));

      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('play and pause state follows the lesson audio',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('Science. Subject 1 of 1.'));
      await settle(tester);
      tester.semantics
          .tap(find.semantics.byLabel('Plants. Topic 1 of 1 in Science.'));
      await settle(tester);

      // The lesson is still being read while the test holds the speech.
      platforms.holdSpeech = Completer<int>();
      tester.semantics
          .tap(find.semantics.byLabel('Plants lesson. Ready to play.'));
      await settle(tester);
      expect(find.semantics.byLabel('Plants lesson. Playing.'), findsOne);
      expect(platforms.tts, contains('speak'));

      tester.semantics.tap(find.semantics.byLabel('Plants lesson. Playing.'));
      await settle(tester);
      expect(find.semantics.byLabel('Plants lesson. Paused.'), findsOne);
      expect(platforms.announcements, contains('Paused.'));

      await unmount(tester);
      semantics.dispose();
    });

    // TalkBack double taps that land in quick succession — a student who
    // heard nothing yet and tapped again — must not undo the first one.

    testWidgets('a repeated Play while the lesson is starting keeps it playing',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('Science. Subject 1 of 1.'));
      await settle(tester);
      tester.semantics
          .tap(find.semantics.byLabel('Plants. Topic 1 of 1 in Science.'));
      await settle(tester);

      platforms.holdSpeech = Completer<int>();
      final play = find.semantics.byLabel('Plants lesson. Ready to play.');
      final node = play.evaluate().single;
      // Two activations before the app has had a frame to respond.
      node.owner!.performAction(node.id, SemanticsAction.tap);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await settle(tester);

      expect(find.semantics.byLabel('Plants lesson. Playing.'), findsOne);
      expect(platforms.tts.where((m) => m == 'speak').length, 1);

      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('only the first of two rapid answer activations counts',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('Science. Subject 1 of 1.'));
      await settle(tester);
      tester.semantics
          .tap(find.semantics.byLabel('Plants. Topic 1 of 1 in Science.'));
      await settle(tester);
      tester.semantics.tap(find.semantics.byLabel('Go to questions'));
      await settle(tester);
      tester.semantics
          .tap(find.semantics.byLabel('Questions for Plants. Ready to start.'));
      await settle(tester);

      final two = find.semantics.byLabel('Option 2: Sand').evaluate().single;
      final three = find.semantics.byLabel('Option 3: Salt').evaluate().single;
      two.owner!.performAction(two.id, SemanticsAction.tap);
      three.owner!.performAction(three.id, SemanticsAction.tap);
      await settle(tester);

      expect(find.semantics.byLabel(RegExp(r'^You chose option 2\.')), findsOne);
      // Still on question 1: the second activation did not answer anything.
      expect(find.semantics.byLabel(RegExp(r'^Question 1 of 2')), findsOne);

      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('a repeated Voice command while the mic opens opens it once',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await settle(tester);

      final voice = find.semantics.byLabel('Voice command').evaluate().single;
      voice.owner!.performAction(voice.id, SemanticsAction.tap);
      // The second double tap lands while the microphone is still opening
      // (during the tone), not yet listening.
      await tester.pump(const Duration(milliseconds: 100));
      expect(platforms.listens, 0);
      platforms.stt.clear();
      voice.owner!.performAction(voice.id, SemanticsAction.tap);
      await settle(tester);

      // It was not torn down and restarted (no stop), and opened once.
      expect(platforms.stt, ['listen']);
      expect(platforms.listens, 1);
      // The button reflects the open microphone, so the student can stop it.
      expect(find.semantics.byLabel('Stop listening'), findsOne);

      await unmount(tester);
      semantics.dispose();
    });
  });

  testWidgets(
      'with TalkBack off, the microphone opens only after the prompt has '
      'finished speaking', (tester) async {
    platforms.holdSpeech = Completer<int>();
    await tester.pumpWidget(_app());
    await settle(tester);

    // The subjects announcement is being spoken.
    expect(platforms.tts, contains('speak'));
    await tester.pump(const Duration(seconds: 2));
    expect(platforms.stt, isNot(contains('listen')),
        reason: 'the mic must not open while our prompt is still playing');

    // The engine reports the end of the utterance; then, after the short
    // settle gap, the mic opens.
    final held = platforms.holdSpeech!;
    platforms.holdSpeech = null;
    held.complete(1);
    await settle(tester);
    expect(platforms.stt, contains('listen'));

    await unmount(tester);
  });

  testWidgets(
      'with TalkBack off, no internet is explained once, the mic stops '
      're-arming, and a tap really opens it again', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await tester.pumpWidget(_app());
    await settle(tester);
    expect(platforms.listens, 1);

    // No connection: the network recognizer fails, the service tries the
    // offline route in the same window, and that fails too (no offline pack).
    await platforms.recognizerError(messenger, 'error_network');
    await settle(tester);
    expect(platforms.listens, 2, reason: 'the offline route was tried');
    await platforms.recognizerError(messenger, 'error_network');
    await settle(tester);
    expect(platforms.spoken.last, contains('need the internet'));

    // Retrying cannot help, so the automatic loop does not keep chiming.
    await tester.pump(const Duration(seconds: 5));
    expect(platforms.listens, 2);

    // "Tap the screen once to try voice again" — and it does.
    await tester.tap(find.textContaining('chart icon'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(platforms.listens, 3);

    await unmount(tester);
  });
}
