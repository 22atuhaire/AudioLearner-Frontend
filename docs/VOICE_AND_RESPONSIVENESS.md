# TalkBack double-tap responsiveness and offline speech — report

Follows [TALKBACK_AND_AUDIO.md](TALKBACK_AND_AUDIO.md). Covers the two tasks in
`instructions_2.md`.

> **Testing status.** Verified with `flutter analyze` and the automated test
> suite (68 tests, including widget tests that drive the hub through TalkBack's
> semantics actions and unit tests that replay the speech plugin's real Android
> callback order). **No testing on an Android device with TalkBack has been
> done.** The device checks are listed at the end.

---

## Part 1 — Slow or missed TalkBack double taps

### What TalkBack does and what we do

A TalkBack double tap is recognised by TalkBack, which then sends
`ACTION_CLICK` to our view on Android's main thread. Flutter forwards that to
the widget's semantics `onTap`, which runs on Flutter's UI thread. Delay can
come from three places:

| Source | Ours? |
|---|---|
| TalkBack waiting to tell a double tap from other gestures (longer if the Accessibility *magnification triple-tap* shortcut is on); TalkBack's gesture timing settings | No — platform |
| Android main thread busy (our plugins run there) or Flutter UI thread busy (our Dart code) | Yes |
| The action runs, but its result is silent or slow, so the student taps again — and the second tap does something else | Yes |

### Root causes found in our code

1. **A second double tap undid the first.** Play lesson did silent work before
   any sound: a fixed 500 ms wait (added earlier to avoid colliding with
   TalkBack's feedback), a platform round-trip, and splitting the lesson text.
   A student who heard nothing tapped again — and because Play/Pause is a
   toggle, the second tap paused it. Voice command had the same shape: a
   second tap while the microphone was still opening could stop it, or tear it
   down and start again. This is the "have to double-tap repeatedly" pattern.
2. **Synchronous work on the UI thread inside the handlers.** Splitting a long
   lesson took ~53 ms and answering a question ~63 ms for an 83,000-character
   lesson on a desktop CPU; several times that on a low-cost phone. Both ran
   inside the Play / Ask handlers, delaying the response and any next tap.
3. **Background microphone loops while TalkBack is in use.** The role screen's
   "Say student or teacher" re-listened forever after one press; the progress
   screen re-armed up to five times. Each window creates a recognizer on the
   Android main thread (the same thread that delivers TalkBack's clicks), holds
   the microphone and plays the recognizer chime.
4. **Buttons kept behind busy states.** The login list stayed behind a spinner
   until speech setup finished — which can include waiting for the microphone
   permission dialog. The join dialog showed no buttons at all while linking
   (up to 75 s on a sleeping server).
5. **TalkBack's speech waiting behind lesson audio (likely, unverified).**
   Android's TTS service plays one utterance at a time across all apps that use
   the same engine, and TalkBack usually uses Google TTS, as we do. Lesson
   segments were ~300 characters (around 20 seconds of slow speech), so
   TalkBack's reply to a swipe or tap during a lesson could wait for the
   segment to end — which feels like the tap did nothing.

Not found: duplicate handlers, debouncing/throttling, disabled buttons, or a
semantics node being recreated under the student's finger. Each control has
one semantics `onTap`; the whole-screen gesture layer is already off and out of
the semantics tree under TalkBack.

### Fixes

- **Play responds at once and a repeat does not undo it.** "Playing" shows in
  the same frame. The 500 ms wait is gone (when TalkBack and the app share an
  engine, the engine already plays their utterances in turn). A repeat
  play/pause while playback is still starting is ignored (`_playbackStarting`,
  a state, not a timer); once audio is on its way, pause works normally.
- **Voice command / Ask a question are idempotent while starting.** A repeat
  activation while the microphone is opening is ignored (`_voiceStarting`);
  once it is listening, the button reads "Stop listening" and a tap stops it.
- **Lesson splitting happens when the lesson opens**, not on Play, and long
  lessons (and question answering) run in a background isolate (`compute`).
- **Shorter lesson utterances under TalkBack** (about one sentence), so any
  wait for TalkBack is a sentence, not a paragraph.
- **Bounded microphone windows**: role screen 1 per press under TalkBack (3 in
  voice-first mode), progress screen 1 per press under TalkBack; a repeat press
  while listening is ignored.
- **Login list shown immediately**; speech setup afterwards and not at all
  under TalkBack on that screen. **Cancel stays available** while joining.
- Listening cues (vibration, click) are no longer awaited, so a slow platform
  reply cannot delay the microphone.

### TalkBack OFF

Same gestures and spoken loop. Play starts without the extra wait; lessons keep
their normal segment length; the role screen stops after 3 silent windows (tap
to listen again) instead of forever.

---

## Part 2 — Offline speech recognition

### What the app did

`speech_to_text` 7.4.0 was always called with `onDevice: false`, so every
session used the default recognizer — on most phones Google's, which needs the
network. Offline, the session failed. Worse, those failures were reported as
silence: the plugin sends "notListening"/"done" first and posts the error a
moment later, and our service ended the session on the first status. So "no
internet" never reached the student — the app just kept listening and going
quiet.

### Is offline recognition possible?

Yes, on suitable phones:

| Android | Mechanism | Can we tell if English works offline? |
|---|---|---|
| 13+ (API 33) | `SpeechRecognizer.createOnDeviceSpeechRecognizer()` | Yes — `checkRecognitionSupport()` → `installedOnDeviceLanguages` |
| 12 (API 31–32) | `createOnDeviceSpeechRecognizer()` if `isOnDeviceRecognitionAvailable()` | No — try it; a missing model fails with `ERROR_LANGUAGE_UNAVAILABLE` / `NOT_SUPPORTED` |
| ≤ 11 | Default recognizer + `RecognizerIntent.EXTRA_PREFER_OFFLINE` | No — works only if Google's offline pack for the language is installed |

The plugin already does the right thing when asked for `onDevice: true`: on
Android 12+ it calls `isOnDeviceRecognitionAvailable()` and
`createOnDeviceSpeechRecognizer()`, otherwise it uses the default recognizer
with `EXTRA_PREFER_OFFLINE`. What it cannot do is say whether the English model
is installed (its `locales()` returns *supported*, not installed, languages,
and the Android side does not implement `hasOnDeviceSupport`).

**Does the Google offline pack work for our app, not just Assistant/Voice
Access?** On Android 13+ the answer is read directly from the phone
(`installedOnDeviceLanguages`). On older phones it depends on Google's
recognizer honouring `EXTRA_PREFER_OFFLINE` with that pack; it usually does, but
the app cannot check in advance — it can only try.

### What was implemented

- `MainActivity.kt`: method channel `audiolearner/speech_capabilities`
  (`query`) returning the API level, whether a default and an on-device
  recognizer exist, and on Android 13+ the installed/pending on-device
  languages (3 s timeout; created/destroyed on the main thread).
- `stt_service.dart`:
  - `chooseRecognition()` picks the route: on-device when an English model is
    installed (the phone's English variant first, then en-US, en-GB, en-IN,
    en-AU — Ugandan English has no offline pack), on-device-then-check on
    Android 12, otherwise network.
  - **Each session tries the other route once** if the first fails in a way
    the other may not: on-device → network on a missing language or a dead
    on-device service; network → offline on no connection. It happens inside
    the same listening window, so every screen benefits unchanged. If the
    second route hears nothing, the student is told the first reason ("no
    internet"), not "nothing heard".
  - A failed on-device route is remembered for the session (re-checked when
    the installed languages change).
  - Errors that arrive after the end-of-capture statuses are now reported:
    the session waits 300 ms for a trailing error before declaring silence
    (the plugin's own ordering, verified in its source).
  - `route` (on-device / network) and `offlineReady` expose the real state.
- Hub: the header shows "Listening (offline)"; under TalkBack the Voice
  command hint ends "works without internet" only when an English model is
  confirmed installed; the no-internet message now says a helper can download
  offline English speech recognition in the phone settings.

Microphone/TTS synchronisation, push-to-talk under TalkBack and the existing
fallbacks are unchanged.

### The four cases

| Internet | On-device English | Result |
|---|---|---|
| On | Available | Recognised on the phone (no data used) |
| On | Unavailable | Network recognizer, as before |
| Off | Available | Recognised on the phone |
| Off | Unavailable | One quick attempt on each route, then "Voice commands need the internet… a helper can download offline English speech recognition…"; buttons/gestures still work; voice is not retried automatically until the student asks |

### How to test with internet off

1. Android 13+ phone: Settings → Google → (Voice / Speech) → **Offline speech
   recognition** (wording varies) → download English (US or UK). On Pixels the
   on-device service is Android System Intelligence; on others "Speech
   Recognition & Synthesis from Google".
2. Install a debug build, sign in once with internet so permissions are granted.
3. Turn on airplane mode (Wi-Fi off).
4. TalkBack on: Voice command → tone → say "next". Expected: it works; the
   button hint says "works without internet".
   TalkBack off: the spoken loop works; the header icon tooltip says
   "Listening (offline)".
5. Remove the offline pack, repeat: expect the no-internet message once, no
   repeated chimes, buttons working.
6. Repeat 3–5 on an Android 12 phone and an Android 10/11 phone (the
   `EXTRA_PREFER_OFFLINE` path).
7. `adb logcat | grep -i -E "speech|SpeechToText|RecognitionService"` shows
   which recognizer was bound.

### Android / Samsung limitations

- **Samsung:** whether `isOnDeviceRecognitionAvailable()` is true depends on
  the phone's configured on-device recognition service. Many Samsung phones
  (especially budget A-series / Go builds) either ship none or route to
  Samsung's own service, whose language list differs from Google's. On those,
  the app takes the network route and, offline, the `EXTRA_PREFER_OFFLINE`
  attempt — which works only if the default recognizer is Google's and its
  offline pack is installed. If Samsung's recognizer is the default, offline
  behaviour is Samsung's and could not be verified here.
- **Android 12** cannot list installed models; the app learns by trying.
- **Android ≤ 11** has no on-device API; offline depends on the Google app's
  pack.
- Offline models are less accurate than the network, especially for accented
  speech and single words like "two". The strict command parser (whole words,
  a bare number for answers) helps; device testing with students should check
  recognition quality.
- The capability query needs the microphone permission; it runs in the
  background after speech is first initialised, so the very first session may
  start on the network and switch to on-device only if that fails.

---

## Files changed

- `lib/features/student/student_learning_hub_screen.dart` — play start without
  dead time and with a start guard; segmenting on lesson open / in an isolate;
  shorter TalkBack segments; voice/ask start guards; question answering in an
  isolate; Cancel while linking; offline state in hint, chip and message.
- `lib/features/auth/role_selection_screen.dart` — bounded, non-reentrant
  role listening; non-blocking cues.
- `lib/features/student/student_progress_screen.dart` — one window per press
  under TalkBack; repeat press ignored.
- `lib/features/student/student_login_screen.dart` — list shown before speech
  setup.
- `lib/shared/services/stt_service.dart` — capabilities, route choice,
  cross-route fallback, error-after-status fix, route state.
- `android/app/src/main/kotlin/com/example/audioapp/MainActivity.kt` —
  capability query.
- Tests: `test/stt_service_test.dart` (rewritten with the real callback
  order; route choice; both fallbacks), `test/learning_hub_accessibility_test.dart`
  (repeated Play, repeated answer, repeated Voice command; offline fallback).

## Remaining limitations / device checks needed

- Measure TalkBack double-tap latency on a target phone (e.g. Samsung A04e)
  with and without a lesson playing; confirm whether TalkBack's speech waits
  behind lesson audio (cause 5). If it does not, the shorter TalkBack segments
  are harmless but unnecessary.
- Confirm the first lesson words do not collide with TalkBack's activation
  feedback now that the 500 ms wait is gone, especially where TalkBack uses a
  different TTS engine from the app.
- Platform gesture delay (magnification shortcut, TalkBack gesture settings)
  cannot be changed by the app; teachers can check those settings.
- All offline cases above need a real phone with and without the offline pack.
