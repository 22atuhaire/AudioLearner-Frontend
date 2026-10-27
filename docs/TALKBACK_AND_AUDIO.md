# TalkBack-first accessibility and audio — engineering report

Scope: the student experience (role selection, login, learning hub, lesson
playback, quiz, voice input, join class, progress). Teacher screens were not
audited.

> **Testing status.** Everything below was verified by static analysis and
> automated tests (unit and widget tests driving the real hub through semantics
> actions). **Nothing has yet been tested on a real Android phone with
> TalkBack.** Section 9 lists what still needs a device.

---

## 1. Current architecture discovered

**Platform.** Flutter app (Riverpod, go_router, Drift). Audio: `flutter_tts`
(lesson reading and app prompts), `speech_to_text` (voice commands). No media
player, no audio-focus handling, no MediaSession.

**Screen-reader detection.** `AccessibilityMode` reads Flutter's
`accessibleNavigation`, which on Android is `isTouchExplorationEnabled()`. That
is the right signal: it is exactly the condition under which TalkBack owns touch
input and speech, which is what makes our gestures unreachable and our TTS a
second voice. It does not detect TalkBack by name (Samsung's screen reader
counts too, Switch Access does not). Read reactively in `build()` via
`MediaQuery`, but the voice loop did not react to it mid-session (now fixed).

**Audio sources and how they met.**

```
Lesson text ─┐
App prompts ─┴─> TtsService (one flutter_tts instance) ─> TTS engine ─┐
TalkBack speech ───────────────────────────────────────> TTS engine ─┴─> speaker
Microphone ─> SttService (speech_to_text) ─> Google recognizer (needs network
                                             unless an offline pack is installed)
```

TalkBack frequently uses the same Google TTS engine as the app. Nothing
coordinated the microphone with TalkBack's speech.

**State.** All learning state lives in `_StudentLearningHubScreenState`
(stage, indices, `_lessonPlaying`, quiz flags). Async flows are cancelled with a
shared `_voiceLoopSession` counter. TTS calls are serialised in `TtsService` by
a generation counter.

## 2. Problems found and 3. root causes

| # | Reported symptom | Root cause |
|---|---|---|
| A | "Next Question" makes TalkBack read from the top (status bar) | The activated button is **removed** by its own action (replaced by the next question's answers), and nothing moved accessibility focus deliberately, so TalkBack fell back to the top of the window. The same happened on every stage change and after choosing an answer. The stage cross-fade briefly kept two stages in the semantics tree. |
| B | Answers get selected without a double tap | (1) The microphone was open while TalkBack read the screen: optional auto-listen opened it on a word-count timer, and push-to-talk stayed open 15 s after a 1.4 s guess. (2) Voice matching used substrings: "done", "phone", "tone" contain "one"; "Question 3 of 5" contains 3; partial results acted immediately. (3) TalkBack's two-finger scroll is passed to the app as a one-finger drag, which fired the custom swipe actions. (4) Option 1 was always drawn highlighted (the gesture cursor), which looked like a pre-selected answer. (5) The "Next question" button called a generic handler that *submits* if the question is unanswered, so a late activation could answer the next question. |
| C | Mic starts while TTS is still speaking | Race in `TtsService`: native `stop()` was skipped until the engine's start callback arrived. In that gap the plugin answered the next `speak()` instantly **without speaking**, the caller took that as "finished", and opened the mic. The plugin's 1 = finished / 0 = stopped result was discarded. Under TalkBack, mic timing was an estimate. |
| D | UI says paused while TalkBack "reads the lesson"; double tap then starts app TTS over it | The lesson card's TalkBack label contained the first 220 characters of the lesson text, so focusing it made TalkBack read lesson content while the app (correctly) said "Ready to play". Separately, flows that silenced the lesson (dialogs, voice command, cloud-sync announcement) left `_lessonPlaying` true, so the card could say "Playing" over silence; leaving the lesson under TalkBack left it talking on another screen. |
| E | "Microphone paused, tap anywhere to speak" — tap does nothing | Under TalkBack a single tap never reaches the app. In normal mode: a refused start left `SttService` permanently marked "listening" (every later start silently refused); no-internet/busy errors were counted as silence and retried until "paused" again; a failed `initialize()` was cached forever. |
| F | Students hear things twice / overlapping | Announcements duplicated what focus would read; the control panel repeated card actions and every quiz answer; button hints said "double tap" twice. |
| G | (found) Wrong grading | The answer letter was derived from the option's position among non-empty options, so with a blank option C the fourth answer was graded as "C". |
| H | (found) Wrong student's progress | Progress screen loaded the first student on the phone, not the signed-in one. |

## 4. Changes implemented and 6. why

**Accessibility focus management** — `AccessibilityFocusTarget`
(`accessibility_service.dart`). When content the student was touching is
replaced, the hub requests focus on the new primary element (stage card,
question heading, answer feedback). It sends Flutter's `FocusSemanticEvent`
after the frame, once per request. *Why this and not announcements:* moving
focus makes TalkBack read the new content **once**, and the next swipe continues
from there; an announcement leaves focus lost. This is the documented use case
for that API and what the Navigator itself uses to restore focus on Android.
Fixes A and most of F.

**Screen-reader mode = no automatic microphone.** Removed the auto-listen
toggle. Under TalkBack the mic opens only via **Voice command** / **Ask a
question** (push-to-talk), with the tone as the prompt (no announcement that
TalkBack would read into the open mic), and only final results act. *Why:*
there is no Android API to know when TalkBack has finished speaking, so any
automatic timing is a guess that lets TalkBack's voice drive the app. Fixes B(1),
part of C.

**Strict voice parsing** — `voice_command_parser.dart`. Whole-word matching;
an answer number is accepted only when the phrase is essentially just the number
("two", "answer two", "my answer is option 2"). Fixes B(2) in both modes.

**Gestures off under TalkBack**; the whole-screen `GestureDetector` is excluded
from semantics in all modes (it was an invisible, unlabelled, tappable node).
Fixes B(3).

**Intent-specific quiz actions.** `_submitAnswer(i)` is the single path that
chooses an answer and is a no-op once answered; `_continueQuiz()` only advances
an answered question. Answer buttons and Next call these directly. Cursor
highlight is not drawn under TalkBack. Fixes B(4), B(5).

**TtsService synchronisation.** Tracks in-flight utterances from the moment
`speak` is called; always stops the engine before a new utterance if one is in
flight; uses the plugin's result; adds `whenIdle()` (engine completion) and
releases a pending speak on engine error/cancel so the service cannot be stuck
busy. The hub waits on `whenIdle()` before every mic window, then a 450 ms
settle gap for room echo. Fixes C. *Not* a longer delay: the wait is on the real
completion signal.

**Truthful voice state** — `SttService`. `startListening` is async and returns
whether the mic really opened; resets on refusal; settles a still-closing
session first; does not cache a failed init; exposes `listening`
(`ValueNotifier`) driven by the recognizer; `classifyError` → `VoiceFailure`
(no speech / busy / no internet / permission / unavailable). The hub retries
busy after a 700 ms cooldown (low-end phones), explains no-internet/permission
once and stops re-arming, and a tap (voice-first) really reopens the mic with
its outcome always reported. The Voice command button reads "Stop listening"
exactly while listening. Fixes E.

**Lesson state owned by the playback loop.** `_endPlaybackRun` clears
"Playing" on every exit unless a newer run (play / resume at new speed) took
over (`_playbackToken`). Navigation and backgrounding stop lesson audio and keep
the position. Card label is short ("Plants lesson. Paused.") with no lesson text;
status shows Playing / Paused / Ready to play; New-lessons notices never
interrupt a lesson. Speed-change confirmations during playback are spoken in
the lesson voice, in sequence. Removed the speculative "retry if TalkBack
cancelled" logic (the real cause was the TtsService race); engine failures are
now reported. Fixes D.

**Superseded:** this change originally kept a 500 ms wait before lesson speech
under TalkBack. It was removed as a cause of slow double taps — see
[VOICE_AND_RESPONSIVENESS.md](VOICE_AND_RESPONSIVENESS.md).

**Mode changes.** The hub observes accessibility changes (TalkBack toggled
mid-session: close mic, pause lesson, re-orient) and app lifecycle (backgrounded:
pause lesson, close mic).

**Concise, non-duplicated semantics.** Stage cards and progress cards read as
one sentence; `onTapHint` replaces hints that repeated "double tap"; the panel
holds only what the card does not (exception: Pause in the lesson, which must be
reachable while it talks); header actions are excluded under TalkBack (they are
at the end of the panel, so Sign out is not the first thing reached); merged
duplicate labels fixed on role, login and join screens.

**Join class under TalkBack.** Every "tap once / tap twice" step has a button
(Start, Speak now, Yes, Say it again, Try again); the mic opens on Speak now,
never on a timer; no-internet/permission point to the typed code.

**Correctness fixes:** G (grade by the option's own label), H (active student).

**Audio priority policy** (documented at the top of `accessibility_service.dart`):
1. TalkBack owns interface feedback; the app never competes with it.
2. Lesson audio plays only on explicit play, until explicit pause/navigation;
   TalkBack speech never pauses it or makes the UI say "paused".
3. App prompts exist in voice-first mode only.
4. The mic opens only when our TTS is idle (engine signal), never during a
   lesson, and under TalkBack only on request.

## 5. Files changed

- `lib/shared/services/accessibility_service.dart` — mode docs, audio policy,
  `AccessibilityFocusTarget`, `customGesturesEnabled`, `onTapHint` buttons.
- `lib/shared/services/tts_service.dart` — in-flight tracking, result-based
  completion, `whenIdle`, pending-speak release.
- `lib/shared/services/stt_service.dart` — async start, `listening`,
  `VoiceFailure`, `classifyError`, retryable init.
- `lib/shared/services/voice_command_parser.dart` — new.
- `lib/features/student/student_learning_hub_screen.dart` — focus management,
  voice loop rewrite, playback ownership, quiz actions, semantics, panel,
  lifecycle/accessibility observers, join dialog.
- `lib/features/student/student_login_screen.dart`,
  `lib/features/student/student_progress_screen.dart`,
  `lib/features/auth/role_selection_screen.dart` — semantics, async listening,
  progress student fix.
- Tests: `test/voice_command_parser_test.dart`, `test/tts_service_test.dart`,
  `test/stt_service_test.dart`, `test/learning_hub_accessibility_test.dart`.

## 7. TalkBack ON after changes

Land on the hub → focus on "Science. Subject 1 of 3." → double tap → focus on
the first topic → double tap → "Plants lesson. Ready to play." → double tap plays
(card becomes "Playing"; TalkBack exploring ducks, never pauses, the lesson) →
double tap pauses ("Paused."). Controls panel: Pause, Read slower/faster, Start
again, Ask a question, Go to questions, Voice command, My progress, Join class,
Sign out. Quiz: focus on "Question 1 of 5. …"; swipe through answers (focus only);
double tap chooses; focus moves to "You chose option 2. Incorrect. The correct
answer is option 1. …"; next swipe is "Next question"; double tap → focus on
"Question 2 of 5. …". The app's own TTS speaks only lesson content (and speed
confirmations during playback). The mic opens only on Voice command / Ask a
question.

## 8. TalkBack OFF after changes

Unchanged design: spoken prompts, swipe/double-tap/long-press/two-finger
gestures, automatic listening after each announcement. Differences: the mic
never opens before the prompt has really finished; voice commands match whole
words; no-internet/permission are explained once instead of looping; a tap after
"Microphone paused" reliably opens the mic; a small header icon shows
Listening / Tap to speak / Voice off; the lesson card shows Paused when a resume
point exists.

## 9. Testing performed

Automated (all passing, `flutter test`: 56 tests, `flutter analyze`: clean):

- Parser: number words inside other words, TalkBack-style phrases, bounds.
- TtsService (mocked channel): completion only on engine end; a new utterance
  stops a queued one before it starts; refused speech reported; `whenIdle`;
  engine error does not leave the service busy.
- SttService (mocked channel): refused start resets and allows retry; errors
  routed with their message; error classification.
- Hub widget tests, TalkBack on: focus sent to subject card, topic card, lesson
  card, first question, feedback, next question; focusing an answer does not
  choose it; no announcement duplicates the focus read; no app TTS and no mic
  in the flow; lesson card has no lesson text; Play → "Playing" → Pause →
  "Paused" + announcement.
- Hub widget tests, TalkBack off: mic does not open while the prompt is still
  being spoken, opens after it ends; no-internet explained once, loop stops,
  tap reopens the mic.

**Not yet tested — needs a device:** real TalkBack honouring the focus moves
(especially right after a node is removed); whether the first lesson words collide with
TalkBack's activation feedback; ducking behaviour; offline / slow network;
permission denied/granted; different TTS engines; low-end phone (e.g. Samsung
A04e) recognizer busy timing. The Android debug build was run separately (see
the hand-off notes).

### Device testing matrix

| Scenario | TalkBack | Internet | Expected result |
|---|---|---|---|
| Browse subjects/topics | ON | OFF | Focus lands on each new card; Next/Previous keep focus and announce briefly |
| Play lesson | ON | OFF | Lesson audio starts ~0.5 s after double tap; card says Playing; no lesson text read by TalkBack |
| Explore while playing | ON | OFF | TalkBack speaks over ducked lesson; lesson not paused, card still Playing |
| Pause lesson | ON | OFF | Audio stops; "Paused."; play resumes at the same word |
| Leave lesson while playing (back / Next topic) | ON | OFF | Lesson stops; no audio on the new screen |
| Quiz start | ON | OFF | Focus on "Question 1 of N. …" |
| Answer exploration | ON | OFF | Swiping answers never chooses one |
| Answer activation | ON | OFF | Double tap chooses; focus on feedback; next swipe = Next question |
| Next question | ON | OFF | Focus on new question; status bar never read |
| Voice command | ON | ON | Tone, then listens ~12 s; button reads "Stop listening" while open |
| Voice command | ON | OFF | "Voice commands need the internet… All the buttons still work." |
| Mic permission denied | ON/OFF | ON | Reason spoken once; buttons/gestures still work |
| Join class | ON | ON | Speak now → tone → code read back → Yes button joins |
| Toggle TalkBack mid-lesson | ON↔OFF | any | Lesson pauses; mode switches; no stray listening |
| App to background while playing | any | any | Lesson pauses, mic closes; resumes orientation on return |
| Voice loop | OFF | ON | Mic opens only after each prompt ends; commands work |
| Voice loop offline | OFF | OFF | Reason spoken once; no repeated chimes; tap retries |
| Mic paused → tap | OFF | ON | Tone; recognizer really listens |
| Normal touch/quiz | OFF | any | Gestures, buttons, grading, visuals unchanged |
| Launch by voice | ON | OFF | See section 10 |

## 10. Known limitations (including "Hey Google, open AudioLearner")

- **Voice launch cannot be guaranteed offline by the app.** "Hey Google, open
  <app>" is handled entirely by Google Assistant / Gemini, which matches the
  spoken name against installed app labels; when it doesn't match, or the
  assistant needs the network, it falls back to a web search. The app has no
  control over this. Android App Actions (`shortcuts.xml` capabilities) require
  the app to be published on Google Play (the current application ID
  `com.example.audioapp` cannot be), work only through Assistant, and are not
  offline. Nothing was implemented, to avoid a fake solution. Closest reliable
  options: keep the launcher label distinctive and easy to say ("Audio Learner");
  place the icon in a fixed home-screen/dock position that TalkBack users learn;
  Google **Voice Access** ("Open Audio Learner") on phones that support its
  on-device recognition. Returning students already resume straight into their
  lessons after launch. (This is based on Android/Google documentation as
  known at the time of writing; behaviour on the school's actual phones should
  be checked.)
- Voice input needs internet unless the phone has Google's offline speech pack.
- Lesson audio uses the media stream and does not request audio focus, so other
  apps' music is not paused and TalkBack ducks the lesson while it speaks.
- No notification/lock-screen controls; the lesson pauses when the app leaves
  the foreground.
- Switch Access users do not get the controls panel (touch exploration is off
  for them).
- Auto-listen under TalkBack was removed (see rationale above).

## 11. Recommended future improvements

1. Device test pass with the matrix above, ideally with students, on the
   school's low-end phones.
2. Request transient audio focus once per lesson playback (not per segment).
3. Media session with notification controls, so a lesson can play and be
   paused from outside the app.
4. Split `student_learning_hub_screen.dart` (≈4,400 lines): voice loop, playback
   and quiz into controllers/notifiers that can be unit-tested without widgets.
5. Give `AppDatabase` an injectable executor for database-backed tests.
6. Audit teacher screens.
7. Real application ID; then evaluate App Actions if the app is published.
