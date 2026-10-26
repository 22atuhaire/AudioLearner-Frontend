import 'package:audioapp/shared/services/stt_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'plugin.csdcorp.com/speech_to_text';
  const channel = MethodChannel(channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Sends a callback from the "platform" to the plugin, as Android does.
  Future<void> fromPlatform(String method, Object? arguments) =>
      messenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );

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

  group('startListening', () {
    late bool platformStarts;
    late int listenCalls;
    // The plugin's SpeechToText is a process-wide singleton that keeps the
    // callbacks of whoever initialised it first — as in the app, where the
    // service is a single provider instance. Share one service here too.
    final stt = SttService();

    setUp(() {
      platformStarts = true;
      listenCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'listen':
            listenCalls++;
            // Android reports "listening" before it answers success.
            if (platformStarts) await fromPlatform('notifyStatus', 'listening');
            return platformStarts;
          case 'stop':
          case 'cancel':
            await fromPlatform('notifyStatus', 'notListening');
            return true;
          default:
            return true;
        }
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

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
      expect(listenCalls, 2);

      await stt.stopListening();
      expect(stt.listening.value, isFalse);
    });

    test('routes an engine error to onError with its message', () async {
      await stt.initialize();
      String? error;
      var done = false;
      await stt.startListening(
        onResult: (_) {},
        onDone: () => done = true,
        onError: (m) => error = m,
      );
      await fromPlatform(
          'notifyError', '{"errorMsg":"error_network","permanent":true}');
      await pumpEventQueue();

      expect(error, 'error_network');
      expect(done, isFalse);
      expect(stt.listening.value, isFalse);
    });
  });
}
