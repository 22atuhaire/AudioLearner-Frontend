import 'dart:async';

import 'package:flutter/foundation.dart';
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
class SttService {
  final speech_to_text.SpeechToText _speech = speech_to_text.SpeechToText();

  bool _isListening = false;
  bool _isAvailable = false;

  /// Bumped every time a session ends through its callbacks, so
  /// [startListening] can tell "ended already, callbacks fired" apart from
  /// "never started".
  int _endedSessions = 0;
  void Function()? _activeOnDone;
  void Function(String message)? _activeOnError;

  /// True only while a session is actually open on the recognizer.
  ///
  /// Driven by the same state the session callbacks use, so a screen showing
  /// it (or a "Stop listening" button label) matches the microphone exactly.
  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);

  /// Whether the service is currently in a listening session.
  bool get isListening => _isListening;

  /// Whether the speech engine initialized successfully.
  bool get isAvailable => _isAvailable;

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
          if (status == 'done' || status == 'notListening') {
            _finishListeningSession();
          }
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
    return _isAvailable;
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

  /// Starts a listening session.
  ///
  /// [onResult]  - called ONCE with the complete, FINAL recognised phrase.
  /// [onPartial] - optional; called with each in-flight partial fragment.
  /// [onDone]    - called once when the session ends with nothing recognised.
  /// [onError]   - optional; called instead of [onDone] when the ENGINE failed
  ///               (busy, client error, no network), with the engine's message.
  ///               Omit it to keep the old behaviour of treating errors as
  ///               "nothing heard".
  /// [onDevice]  - prefer an installed on-device model (offline). Default false.
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
    bool onDevice = false,
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

    _isListening = true;
    _activeOnDone = onDone;
    _activeOnError = onError;
    final endedBefore = _endedSessions;
    var deliveredFinal = false;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();

          if (result.finalResult) {
            if (words.isNotEmpty && !deliveredFinal) {
              deliveredFinal = true;
              // Final result delivered -> this session ends successfully, so
              // neither the "nothing heard" nor the error callback may fire
              // afterwards (some engines emit a trailing error after a result).
              _activeOnDone = null;
              _activeOnError = null;
              onResult(words);
            }
            _finishListeningSession();
            return;
          }

          if (words.isNotEmpty && onPartial != null) {
            onPartial(words);
          }
        },
        listenOptions: speech_to_text.SpeechListenOptions(
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: speech_to_text.ListenMode.confirmation,
          // When true, restricts recognition to an installed on-device model so
          // voice input keeps working with no internet. Defaults to false because
          // forcing on-device on a phone WITHOUT an offline pack makes listening
          // fail outright; callers opt in only where an offline pack is expected.
          // Offline-without-a-pack is covered by the gesture fallback regardless.
          onDevice: onDevice,
        ),
      );
    } catch (_) {
      if (_endedSessions != endedBefore) return true;
      _resetSession();
      return false;
    }

    // A very short session can already have ended (error or result) while the
    // start was in flight. Its callbacks have run, so the caller is informed.
    if (_endedSessions != endedBefore) return true;

    // The platform announces "listening" before it reports success, so a
    // session that really opened is visible here. If it is not, the native
    // side refused (still busy) and no callback will follow.
    if (!_speech.isListening) {
      _resetSession();
      return false;
    }
    listening.value = true;
    return true;
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
    _isListening = false;
    _activeOnDone = null;
    _activeOnError = null;
    listening.value = false;
  }

  /// Ends the active session exactly once, routing to [_activeOnError] when the
  /// engine failed and a caller asked for errors, otherwise to [_activeOnDone].
  ///
  /// Callers that don't pass an `onError` keep the previous behaviour — an
  /// engine error still arrives as "done" — so existing screens are unaffected.
  void _finishListeningSession({String? error}) {
    if (!_isListening) return;

    final onDone = _activeOnDone;
    final onError = _activeOnError;
    _resetSession();
    _endedSessions++;

    if (error != null && onError != null) {
      onError(error);
    } else {
      onDone?.call();
    }
  }
}
