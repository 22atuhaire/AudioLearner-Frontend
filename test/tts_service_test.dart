import 'dart:async';

import 'package:audioapp/shared/services/tts_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the native flutter_tts plugin. `speak` stays pending until
/// the test finishes it (as the real plugin does with awaitSpeakCompletion),
/// and `stop` answers any pending speak with 0, as the real plugin does.
class _FakeTtsPlatform {
  final calls = <String>[];
  final pending = <Completer<int>>[];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'getLanguages':
        return ['en-US'];
      case 'speak':
        final c = Completer<int>();
        pending.add(c);
        return c.future;
      case 'stop':
        for (final c in pending) {
          if (!c.isCompleted) c.complete(0);
        }
        return 1;
      default:
        return 1;
    }
  }

  /// The engine finishes the oldest unfinished utterance.
  void finishSpeaking() =>
      pending.firstWhere((c) => !c.isCompleted).complete(1);

  List<String> get speechCalls =>
      calls.where((c) => c == 'speak' || c == 'stop').toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late _FakeTtsPlatform platform;
  late TtsService tts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    platform = _FakeTtsPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, platform.handle);
    tts = TtsService();
    await tts.initialize();
    platform.calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('speakAndWait is true only once the engine reports the end', () async {
    var done = false;
    final result = tts.speakAndWait('Question one.').then((r) {
      done = true;
      return r;
    });
    await pumpEventQueue();
    expect(done, isFalse, reason: 'must not resolve before the engine is done');
    expect(tts.isBusy, isTrue);

    platform.finishSpeaking();
    expect(await result, isTrue);
    expect(tts.isBusy, isFalse);
  });

  test('a new utterance stops a queued one even before it started', () async {
    // The engine has accepted the first utterance but not reported its start
    // (no start callback). The old code skipped the native stop here, so the
    // plugin answered the second speak instantly without speaking it.
    final first = tts.speakAndWait('A long prompt that is still queued.');
    await pumpEventQueue();
    final second = tts.speakAndWait('The next prompt.');
    await pumpEventQueue();

    expect(platform.speechCalls, ['speak', 'stop', 'speak']);
    expect(await first, isFalse, reason: 'the first one was interrupted');

    platform.finishSpeaking();
    expect(await second, isTrue);
  });

  test('an utterance the engine refuses is reported as not spoken', () async {
    final result = tts.speakAndWait('Hello.');
    await pumpEventQueue();
    // What the plugin answers when it refuses to speak.
    platform.pending.single.complete(0);
    expect(await result, isFalse);
  });

  test('whenIdle waits for the engine to finish speaking', () async {
    unawaited(tts.speakAndWait('Say your command after the tone.'));
    await pumpEventQueue();

    var idle = false;
    unawaited(tts.whenIdle().then((_) => idle = true));
    await pumpEventQueue();
    expect(idle, isFalse);

    platform.finishSpeaking();
    await pumpEventQueue();
    expect(idle, isTrue);
  });

  test('an engine error releases the pending speak so the app is not stuck '
      'busy', () async {
    unawaited(tts.speakAndWait('Hello.'));
    await pumpEventQueue();
    expect(tts.isBusy, isTrue);

    // The plugin reports an error but never answers the pending speak call.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'flutter_tts',
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('speak.onError', 'engine error')),
      (_) {},
    );
    await pumpEventQueue();

    expect(platform.calls, contains('stop'));
    expect(tts.isBusy, isFalse);
  });
}
