import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech_to_text;

/// Why a listening attempt produced nothing, in terms a student can act on.
///
/// The recognizer reports a dozen engine codes. Collapsing them matters
/// because each group needs a different response: silence is normal and the
/// mic can simply re-open; a busy recognizer needs a short pause first; no
/// internet or no permission will fail every time until something changes,
/// so retrying just plays the recognizer chime again and again — which is how
/// "Microphone paused, tap to speak" turned into a loop that never listened.
enum VoiceFailure {
  /// Nothing was said (or nothing usable). Normal; re-listening is fine.
  noSpeech,

  /// The recognizer is still releasing the previous session. Low-end phones
  /// need a beat before it can start again.
  busy,

  /// The recognizer needs a network connection it does not have.
  noInternet,

  /// The microphone permission is denied.
  permissionDenied,

  /// No usable speech recognizer on this phone.
  unavailable,
}

/// Which recognizer a listening session is using.
enum RecognitionRoute {
  /// Speech is recognised on the phone (no internet needed).
  ///
  /// On Android 12+ with an on-device recognition service this is
  /// `SpeechRecognizer.createOnDeviceSpeechRecognizer()`. On older phones it is
  /// the default (Google) recognizer asked to work offline
  /// (`RecognizerIntent.EXTRA_PREFER_OFFLINE`), which only succeeds when the
  /// offline language pack is installed. The speech_to_text plugin makes that
  /// choice when asked for `onDevice`.
  onDevice,

  /// The default recognizer, which normally sends audio to Google's servers.
  network,
}

/// What the phone reports about its speech recognizers (see MainActivity.kt).
@immutable
class SpeechCapabilities {
  const SpeechCapabilities({
    this.network = true,
    this.onDevice = false,
    this.installedOnDeviceLanguages,
    this.sdk,
  });

  /// Nothing known (not Android, or the query failed): behave as before and
  /// let the default recognizer decide.
  static const unknown = SpeechCapabilities();

  factory SpeechCapabilities.fromMap(Map<String, Object?> map) {
    List<String>? languages(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : null;
    return SpeechCapabilities(
      network: map['network'] != false,
      onDevice: map['onDevice'] == true,
      installedOnDeviceLanguages: languages(map['installed']),
      sdk: map['sdk'] is int ? map['sdk'] as int : null,
    );
  }

  /// A default (usually network-backed) recognizer exists.
  final bool network;

  /// An on-device recognition service exists (Android 12+).
  final bool onDevice;

  /// Languages whose on-device model is installed (Android 13+). Null when the
  /// phone cannot say — Android 12, or the query did not answer.
  final List<String>? installedOnDeviceLanguages;

  final int? sdk;
}

/// The recognizer to try first, and the language to ask it for.
@immutable
class RecognitionPlan {
  const RecognitionPlan(this.route, {this.localeId});
  final RecognitionRoute route;
  final String? localeId;
}

/// Chooses on-device recognition when it can work, otherwise network.
///
/// Lessons are in English, so on-device is chosen only when an English model
/// is installed, preferring the phone's own English variant, then the common
/// Google packs. (Ugandan English, en-UG, has no offline pack; a phone set to
/// it can still recognise offline with the US or UK pack.) When the phone
/// cannot list its models (Android 12) on-device is tried and the service
/// falls back to network if the language turns out to be missing.
RecognitionPlan chooseRecognition(
  SpeechCapabilities caps, {
  String? deviceLocale,
}) {
  const network = RecognitionPlan(RecognitionRoute.network);
  if (!caps.onDevice) return network;
  final installed = caps.installedOnDeviceLanguages;
  if (installed == null) return const RecognitionPlan(RecognitionRoute.onDevice);

  String norm(String s) => s.replaceAll('_', '-').toLowerCase();
  final english = installed.where((l) => norm(l).startsWith('en')).toList();
  if (english.isEmpty) return network;
  RecognitionPlan use(String l) =>
      RecognitionPlan(RecognitionRoute.onDevice, localeId: l);

  final device = deviceLocale == null ? null : norm(deviceLocale);
  for (final l in english) {
    if (norm(l) == device) return use(l);
  }
  for (final preferred in const ['en-us', 'en-gb', 'en-in', 'en-au']) {
    for (final l in english) {
      if (norm(l) == preferred) return use(l);
    }
  }
  return use(english.first);
}

/// One caller's listening request. It can span two recognizer attempts when
/// the first route fails in a way the other may not (see [SttService]).
class _Session {
  _Session({
    required this.onResult,
    required this.onPartial,
    required this.onDone,
    required this.onError,
    required this.listenFor,
    required this.pauseFor,
  });

  final void Function(String words) onResult;
  final void Function(String words)? onPartial;
  void Function()? onDone;
  void Function(String message)? onError;
  final Duration listenFor;
  final Duration pauseFor;

  RecognitionRoute route = RecognitionRoute.network;
  final tried = <RecognitionRoute>{};
  bool heardSomething = false;
  bool deliveredFinal = false;

  /// The error that made the first route give up, reported if the second
  /// route ends without hearing anything either.
  String? firstError;
}

/// Global Speech-to-Text service for the AudioApp platform.
///
/// Wraps the `speech_to_text` package behind a small callback-based API so
/// every call-site stays decoupled from the engine's details.
///
/// Typical usage:
///   1. Await [initialize] (cheap after the first success).
///   2. Await [startListening]; `false` means the microphone did NOT open.
///   3. Call [stopListening] when done, or let it end on silence/timeout.
///
/// [listening] always reflects whether the recognizer is really capturing
/// audio, so the UI can never claim "listening" while the engine is idle.
///
/// ## Offline first
///
/// Each session starts on the route [chooseRecognition] picks — on-device
/// when an English model is installed. If that route fails in a way the other
/// may not (the on-device language is missing; the network is unreachable)
/// before anything was heard, the session silently tries the other route
/// once. Callers see one listening window either way.
class SttService {
  final speech_to_text.SpeechToText _speech = speech_to_text.SpeechToText();

  static const MethodChannel _capabilitiesChannel =
      MethodChannel('audiolearner/speech_capabilities');

  bool _isListening = false;
  bool _isAvailable = false;
  _Session? _session;

  /// Bumped every time a session ends through its callbacks, so
  /// [startListening] can tell "ended already, callbacks fired" apart from
  /// "never started".
  int _endedSessions = 0;

  /// The recognizer reports "notListening" and "done" BEFORE the error that
  /// caused them: the speech_to_text Android plugin sends the statuses at once
  /// and posts the error to the main looper. Ending the session on the status
  /// therefore reported every engine failure — no internet included — as
  /// "nothing heard", and the error that followed was dropped. A session that
  /// stops capturing waits this long for a trailing error before it is
  /// reported as silence.
  static const Duration _errorGrace = Duration(milliseconds: 300);
  Timer? _endTimer;

  SpeechCapabilities _capabilities = SpeechCapabilities.unknown;

  /// The on-device route failed as unusable in this app session; start on
  /// the network until the phone's capabilities change.
  bool _onDeviceUnusable = false;

  /// True only while a session is actually open on the recognizer.
  ///
  /// Driven by the same state the session callbacks use, so a screen showing
  /// it (or a "Stop listening" button label) matches the microphone exactly.
  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);

  /// The recognizer the current (or last) session used.
  final ValueNotifier<RecognitionRoute?> route =
      ValueNotifier<RecognitionRoute?>(null);

  /// Whether the service is currently in a listening session.
  bool get isListening => _isListening;

  /// Whether the speech engine initialized successfully.
  bool get isAvailable => _isAvailable;

  SpeechCapabilities get capabilities => _capabilities;

  /// True when the phone has confirmed an installed English on-device model,
  /// so voice input should work with no internet.
  bool get offlineReady =>
      !_onDeviceUnusable &&
      _capabilities.installedOnDeviceLanguages != null &&
      chooseRecognition(_capabilities).route == RecognitionRoute.onDevice;

  /// The phone listed its on-device models (Android 13+) and English is not
  /// among them, so an offline attempt cannot succeed.
  bool get _knownNoEnglishModel =>
      _capabilities.onDevice &&
      _capabilities.installedOnDeviceLanguages != null &&
      chooseRecognition(_capabilities).route == RecognitionRoute.network;

  /// Initialises the STT back-end. Returns `true` when recognition is available.
  ///
  /// A failure is NOT cached: the first attempt can fail because the student
  /// had not answered the microphone permission dialog yet, and remembering
  /// that failure made voice input dead for the rest of the session.
  Future<bool> initialize() async {
    if (_isAvailable) return true;

    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') _captureEnded();
        },
        onError: (error) {
          // Surface the reason so callers can tell an ENGINE failure (busy,
          // client error, no network) from genuine silence.
          _finishListeningSession(error: error.errorMsg);
        },
      );
    } catch (_) {
      _isAvailable = false;
    }
    // Asked after initialize, when the microphone permission has been
    // answered: installed languages can only be listed with it. Not awaited:
    // the query can take seconds on some phones, and the first Voice command
    // must not wait for it. Until it answers, sessions start on the network
    // and still reach the on-device route if the network is unavailable.
    if (_isAvailable) unawaited(refreshCapabilities());
    return _isAvailable;
  }

  /// Re-reads which recognizers and on-device languages the phone has (a
  /// helper may have just downloaded the offline pack).
  Future<void> refreshCapabilities() async {
    try {
      final map = await _capabilitiesChannel
          .invokeMapMethod<String, Object?>('query')
          .timeout(const Duration(seconds: 4));
      if (map == null) return;
      final next = SpeechCapabilities.fromMap(map);
      if (!listEquals(next.installedOnDeviceLanguages,
          _capabilities.installedOnDeviceLanguages)) {
        _onDeviceUnusable = false;
      }
      _capabilities = next;
    } on MissingPluginException {
      // Not Android (or a test): keep the plugin's default behaviour.
    } catch (_) {
      // Unknown — keep what we had.
    }
  }

  /// Explains why [initialize] returned false.
  Future<VoiceFailure> unavailableReason() async {
    try {
      if (!await _speech.hasPermission) return VoiceFailure.permissionDenied;
    } catch (_) {
      // Fall through — without a permission answer, report "unavailable".
    }
    return VoiceFailure.unavailable;
  }

  /// Maps an engine error message (`error_network`, `error_busy`, ...) to the
  /// [VoiceFailure] a student-facing message is chosen from.
  static VoiceFailure classifyError(String message) {
    final m = message.toLowerCase();
    if (m.contains('network') ||
        m.contains('server') ||
        m.contains('too_many_requests')) {
      return VoiceFailure.noInternet;
    }
    if (m.contains('permission')) return VoiceFailure.permissionDenied;
    if (m.contains('busy') || m.contains('client') || m.contains('audio')) {
      return VoiceFailure.busy;
    }
    if (m.contains('language')) return VoiceFailure.unavailable;
    // error_no_match / error_speech_timeout and anything unknown: the student
    // simply was not understood.
    return VoiceFailure.noSpeech;
  }

  /// Whether [error] on [route] means the OTHER route is worth trying.
  static bool _otherRouteMayWork(RecognitionRoute route, String error) {
    final m = error.toLowerCase();
    return switch (route) {
      // Model missing, language unsupported, or the on-device service died.
      RecognitionRoute.onDevice => m.contains('language') ||
          m.contains('server_disconnected') ||
          m.contains('recognizer'),
      // No connection: an installed offline pack may still work.
      RecognitionRoute.network => classifyError(m) == VoiceFailure.noInternet,
    };
  }

  /// Starts a listening session.
  ///
  /// [onResult]  - called ONCE with the complete, FINAL recognised phrase.
  /// [onPartial] - optional; called with each in-flight partial fragment.
  /// [onDone]    - called once when the session ends with nothing recognised.
  /// [onError]   - optional; called instead of [onDone] when the ENGINE failed
  ///               (busy, client error, no network), with the engine's message.
  ///               Omit it to keep the old behaviour of treating errors as
  ///               "nothing heard".
  ///
  /// Resolves to `false` when the microphone did not open (engine unavailable,
  /// a session already running, or the platform refused to start). No callback
  /// will ever arrive in that case, so the caller must recover itself instead
  /// of waiting.
  Future<bool> startListening({
    required void Function(String words) onResult,
    void Function(String words)? onPartial,
    void Function()? onDone,
    void Function(String message)? onError,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 8),
  }) async {
    if (_isListening || !_isAvailable) return false;

    // A previous session that is still winding down on the platform side makes
    // the native start silently return false. Settle it first; its trailing
    // status callbacks arrive before cancel() resolves, so they can't be
    // mistaken for the end of the new session.
    if (_speech.isListening) {
      try {
        await _speech.cancel();
      } catch (_) {}
    }

    final session = _Session(
      onResult: onResult,
      onPartial: onPartial,
      onDone: onDone,
      onError: onError,
      listenFor: listenFor,
      pauseFor: pauseFor,
    );
    _session = session;
    _isListening = true;
    final endedBefore = _endedSessions;

    final plan = _onDeviceUnusable
        ? const RecognitionPlan(RecognitionRoute.network)
        : chooseRecognition(
            _capabilities,
            deviceLocale: PlatformDispatcher.instance.locale.toLanguageTag(),
          );
    var started = await _listen(session, plan);
    // The on-device recognizer could not even start: try the network at once.
    if (!started &&
        _endedSessions == endedBefore &&
        _session == session &&
        plan.route == RecognitionRoute.onDevice) {
      _onDeviceUnusable = true;
      started = await _listen(
          session, const RecognitionPlan(RecognitionRoute.network));
    }

    // A very short session can already have ended (error or result) while the
    // start was in flight. Its callbacks have run, so the caller is informed.
    if (_endedSessions != endedBefore) return true;
    if (!started) {
      _resetSession();
      return false;
    }
    listening.value = true;
    return true;
  }

  /// Opens the recognizer for [session] on [plan]'s route. True when the
  /// platform reports it is capturing.
  Future<bool> _listen(_Session session, RecognitionPlan plan) async {
    // A capture-ended signal still pending belongs to the previous attempt.
    _endTimer?.cancel();
    _endTimer = null;
    session.route = plan.route;
    session.tried.add(plan.route);
    route.value = plan.route;
    try {
      await _speech.listen(
        onResult: (result) => _onResult(session, result),
        listenOptions: speech_to_text.SpeechListenOptions(
          listenFor: session.listenFor,
          pauseFor: session.pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: speech_to_text.ListenMode.confirmation,
          onDevice: plan.route == RecognitionRoute.onDevice,
          localeId: plan.localeId,
        ),
      );
    } catch (_) {
      return false;
    }
    // The platform announces "listening" before it reports success, so a
    // session that really opened is visible here. If it is not, the native
    // side refused (still busy) and no callback will follow.
    return _speech.isListening;
  }

  void _onResult(_Session session, SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    if (words.isNotEmpty) session.heardSomething = true;

    if (r.finalResult) {
      if (words.isNotEmpty && !session.deliveredFinal) {
        session.deliveredFinal = true;
        // Final result delivered -> this session ends successfully, so
        // neither the "nothing heard" nor the error callback may fire
        // afterwards (some engines emit a trailing error after a result).
        session.onDone = null;
        session.onError = null;
        session.onResult(words);
      }
      if (_session == session) _finishListeningSession();
      return;
    }

    if (words.isNotEmpty) session.onPartial?.call(words);
  }

  /// The recognizer stopped capturing. Show that at once; report the end of
  /// the session only if no error follows (see [_errorGrace]).
  void _captureEnded() {
    if (!_isListening) return;
    listening.value = false;
    _endTimer ??= Timer(_errorGrace, () {
      _endTimer = null;
      _finishListeningSession();
    });
  }

  /// Ends the current listening session. Safe to call even when not listening.
  Future<void> stopListening() async {
    _resetSession();
    if (_isAvailable) {
      await _speech.stop();
    }
  }

  /// Stops any active session and releases the engine.
  Future<void> dispose() async {
    _resetSession();
    if (_isAvailable) {
      await _speech.stop();
    }
  }

  void _resetSession() {
    _endTimer?.cancel();
    _endTimer = null;
    _isListening = false;
    _session = null;
    listening.value = false;
  }

  /// Ends the active session exactly once, routing to its onError when the
  /// engine failed and the caller asked for errors, otherwise to its onDone —
  /// unless the failure is one the other recognizer may not have, in which
  /// case the same session continues there.
  ///
  /// Callers that don't pass an `onError` keep the previous behaviour — an
  /// engine error still arrives as "done" — so existing screens are unaffected.
  void _finishListeningSession({String? error}) {
    _endTimer?.cancel();
    _endTimer = null;
    final session = _session;
    if (!_isListening || session == null) return;

    if (error != null && !session.heardSomething) {
      final other = session.route == RecognitionRoute.onDevice
          ? RecognitionRoute.network
          : RecognitionRoute.onDevice;
      final otherAvailable = other == RecognitionRoute.network
          ? _capabilities.network
          : !_onDeviceUnusable && !_knownNoEnglishModel;
      if (!session.tried.contains(other) &&
          otherAvailable &&
          _otherRouteMayWork(session.route, error)) {
        if (session.route == RecognitionRoute.onDevice) {
          _onDeviceUnusable = true;
        }
        session.firstError ??= error;
        unawaited(_switchRoute(session, other));
        return;
      }
    }
    // The second route heard nothing either: the first failure is the reason
    // the student needs (usually "no internet"), not "nothing heard".
    final reported = error ?? (session.heardSomething ? null : session.firstError);

    final onDone = session.onDone;
    final onError = session.onError;
    _resetSession();
    _endedSessions++;

    if (reported != null && onError != null) {
      onError(reported);
    } else {
      onDone?.call();
    }
  }

  Future<void> _switchRoute(_Session session, RecognitionRoute next) async {
    listening.value = false;
    try {
      await _speech.cancel();
    } catch (_) {}
    if (_session != session || !_isListening) return; // stopped meanwhile
    final started = await _listen(
      session,
      RecognitionPlan(next,
          localeId: next == RecognitionRoute.onDevice
              ? chooseRecognition(_capabilities).localeId
              : null),
    );
    if (_session != session || !_isListening) return;
    if (started) {
      listening.value = true;
    } else {
      _finishListeningSession(error: session.firstError ?? 'error_client');
    }
  }
}
