import 'package:audioapp/shared/services/stt_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'plugin.csdcorp.com/speech_to_text';
  const channel = MethodChannel(channelName);
  const capabilitiesChannel = MethodChannel('audiolearner/speech_capabilities');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Sends a callback from the "platform" to the plugin, as Android does.
  Future<void> fromPlatform(String method, Object? arguments) =>
      messenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );

  /// An engine failure in the order the Android plugin really delivers it:
  /// the statuses first, the error one looper turn later.
  Future<void> engineError(String error) async {
    await fromPlatform('notifyStatus', 'notListening');
    await fromPlatform('notifyStatus', 'doneNoResult');
    await fromPlatform(
        'notifyError', '{"errorMsg":"$error","permanent":true}');
    await pumpEventQueue();
  }

  /// The window closes having heard nothing.
  Future<void> silence() async {
    await fromPlatform('notifyStatus', 'notListening');
    await fromPlatform('notifyStatus', 'doneNoResult');
    await pumpEventQueue();
  }

  group('classifyError', () {
    test('groups engine errors by what the student can do about them', () {
      expect(SttService.classifyError('error_network'),
          VoiceFailure.noInternet);
      expect(SttService.classifyError('error_network_timeout'),
          VoiceFailure.noInternet);
      expect(SttService.classifyError('error_server_disconnected'),
          VoiceFailure.noInternet);
      expect(SttService.classifyError('error_permission'),
          VoiceFailure.permissionDenied);
      expect(SttService.classifyError('error_busy'), VoiceFailure.busy);
      expect(SttService.classifyError('error_client'), VoiceFailure.busy);
      expect(SttService.classifyError('error_no_match'),
          VoiceFailure.noSpeech);
      expect(SttService.classifyError('error_speech_timeout'),
          VoiceFailure.noSpeech);
      expect(SttService.classifyError('error_language_unavailable'),
          VoiceFailure.unavailable);
    });
  });

  group('chooseRecognition', () {
    test('uses the network when there is no on-device recognizer', () {
      final plan = chooseRecognition(
          const SpeechCapabilities(onDevice: false), deviceLocale: 'en-US');
      expect(plan.route, RecognitionRoute.network);
    });

    test('uses an installed English model, preferring the phone locale', () {
      const caps = SpeechCapabilities(
          onDevice: true, installedOnDeviceLanguages: ['fr-FR', 'en-US', 'en-GB']);
      expect(chooseRecognition(caps, deviceLocale: 'en_GB').localeId, 'en-GB');
      expect(chooseRecognition(caps, deviceLocale: 'en-GB').route,
          RecognitionRoute.onDevice);
    });

    test('a Ugandan-English phone still uses an installed US/UK model', () {
      const caps = SpeechCapabilities(
          onDevice: true, installedOnDeviceLanguages: ['en-GB', 'en-US']);
      final plan = chooseRecognition(caps, deviceLocale: 'en-UG');
      expect(plan.route, RecognitionRoute.onDevice);
      expect(plan.localeId, 'en-US');
    });

    test('uses the network when no English model is installed', () {
      const caps = SpeechCapabilities(
          onDevice: true, installedOnDeviceLanguages: ['fr-FR']);
      expect(chooseRecognition(caps).route, RecognitionRoute.network);
    });

    test('tries on-device when the phone cannot list its models', () {
      // Android 12: on-device service present, language list unavailable.
      const caps = SpeechCapabilities(onDevice: true);
      final plan = chooseRecognition(caps);
      expect(plan.route, RecognitionRoute.onDevice);
      expect(plan.localeId, isNull);
    });
  });

  group('startListening', () {
    late bool platformStarts;
    late List<Map<Object?, Object?>> listens;
    late Map<String, Object?>? capabilities;
    var capturing = false;
    // The plugin's SpeechToText is a process-wide singleton that keeps the
    // callbacks of whoever initialised it first — as in the app, where the
    // service is a single provider instance. Share one service here too.
    // (Tests below therefore run in order and build on each other's routing
    // state, as one app session would.)
    final stt = SttService();

    setUp(() {
      platformStarts = true;
      listens = [];
      capabilities = null;
      capturing = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'listen':
            listens.add(call.arguments as Map<Object?, Object?>);
            // Android reports "listening" before it answers success.
            if (platformStarts) {
              capturing = true;
              await fromPlatform('notifyStatus', 'listening');
            }
            return platformStarts;
          case 'stop':
          case 'cancel':
            if (capturing) {
              capturing = false;
              await fromPlatform('notifyStatus', 'notListening');
            }
            return true;
          default:
            return true;
        }
      });
      messenger.setMockMethodCallHandler(
          capabilitiesChannel, (call) async => capabilities);
    });

    tearDown(() async {
      await stt.stopListening();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(capabilitiesChannel, null);
    });

    test('reports a refused start and stays ready for the next attempt',
        () async {
      expect(await stt.initialize(), isTrue);

      platformStarts = false;
      final refused = await stt.startListening(onResult: (_) {});
      expect(refused, isFalse);
      // Before the fix the service stayed marked "listening" here, so every
      // later attempt — like tapping after "Microphone paused" — was refused
      // without a sound.
      expect(stt.isListening, isFalse);
      expect(stt.listening.value, isFalse);

      platformStarts = true;
      final started = await stt.startListening(onResult: (_) {});
      expect(started, isTrue);
      expect(stt.listening.value, isTrue);
      expect(listens, hasLength(2));
    });

    test('an engine error that follows the end-of-capture statuses still '
        'reaches onError', () async {
      await stt.initialize();
      String? error;
      var done = false;
      await stt.startListening(
        onResult: (_) {},
        onDone: () => done = true,
        onError: (m) => error = m,
      );
      await engineError('error_busy');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Ending on the first status used to report this as "nothing heard".
      expect(error, 'error_busy');
      expect(done, isFalse);
      expect(stt.listening.value, isFalse);
    });

    test('silence is still reported as nothing heard', () async {
      await stt.initialize();
      var done = false;
      String? error;
      await stt.startListening(
        onResult: (_) {},
        onDone: () => done = true,
        onError: (m) => error = m,
      );
      await silence();
      expect(stt.listening.value, isFalse, reason: 'shown closed at once');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(done, isTrue);
      expect(error, isNull);
    });

    test('starts on-device with the installed English model', () async {
      capabilities = {
        'sdk': 34,
        'network': true,
        'onDevice': true,
        'installed': ['fr-FR', 'en-US'],
      };
      await stt.refreshCapabilities();
      expect(stt.offlineReady, isTrue);

      await stt.startListening(onResult: (_) {});
      expect(listens.single['onDevice'], isTrue);
      expect(listens.single['localeId'], 'en-US');
      expect(stt.route.value, RecognitionRoute.onDevice);
    });

    test('offline, a network-only start falls back to the offline route, and '
        'reports "no internet" if that hears nothing too', () async {
      // An older phone: no on-device service, maybe an offline pack.
      capabilities = {'sdk': 30, 'network': true, 'onDevice': false};
      await stt.refreshCapabilities();
      String? error;
      var done = false;
      await stt.startListening(
        onResult: (_) {},
        onDone: () => done = true,
        onError: (m) => error = m,
      );
      expect(listens.single['onDevice'], isFalse);

      await engineError('error_network');
      expect(listens, hasLength(2));
      expect(listens.last['onDevice'], isTrue, reason: 'tried offline');
      expect(error, isNull, reason: 'still listening on the second route');
      expect(stt.listening.value, isTrue);

      await silence();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(error, 'error_network');
      expect(done, isFalse);
    });

    test('a missing on-device language falls back to the network in the same '
        'window', () async {
      capabilities = {
        'sdk': 34,
        'network': true,
        'onDevice': true,
        'installed': ['en-GB'],
      };
      await stt.refreshCapabilities();
      String? error;
      await stt.startListening(onResult: (_) {}, onError: (m) => error = m);
      expect(listens.single['onDevice'], isTrue);

      await engineError('error_language_unavailable');
      expect(listens, hasLength(2));
      expect(listens.last['onDevice'], isFalse);
      expect(error, isNull);
      expect(stt.listening.value, isTrue);
      expect(stt.route.value, RecognitionRoute.network);
      // Remembered: the next session starts on the network.
      expect(stt.offlineReady, isFalse);
    });
  });
}
