# AudioLearner — TalkBack-First Accessibility, Audio UX & Interaction Improvement

## Role

Act as a senior Android accessibility engineer, Android audio/voice UX engineer, and codebase investigator.

You are working on **AudioLearner**, a mobile-based interactive audio learning platform designed primarily for visually impaired students in Ugandan schools.

--ENSURE EVERYTHING IS UPTO DATE WITH ORIGIN MAIN

We have already tested the application with blind students.

The testing showed us something important:

> **AudioLearner works much better when TalkBack is treated as a first-class interaction mode rather than simply something the application detects.**

The goal of this task is therefore **not merely to patch a few TalkBack bugs**.

Your job is to investigate the entire application and improve the architecture and user experience so that:

1. The application is easy and predictable to use with TalkBack ON.
2. The application remains fully usable with TalkBack OFF.
3. TalkBack and AudioLearner's own audio/TTS do not fight each other.
4. Touch gestures and accessibility gestures work predictably.
5. Voice input remains useful where internet connectivity is available.
6. Core learning activities remain possible without voice input.
7. The student should never need to understand Android internals to use the application.
8. Accessibility behavior should feel intentional and designed, not like a collection of accessibility patches.

---

# IMPORTANT: DO NOT START CODING IMMEDIATELY

Before changing code, thoroughly inspect the project.

Do not assume the current implementation is correct.

Do not assume the existing TalkBack detection, TTS, microphone state, audio playback, quiz state, or gesture handling architecture is the best approach.

First build a mental model of the application.

---

# PHASE 1 — COMPLETE CODEBASE INVESTIGATION

Go through the entire repository and collect as much relevant information as possible.

Inspect at minimum:

- Android project structure
- Activities
- Fragments
- Composables/views
- Navigation
- ViewModels
- repositories
- services
- audio player implementation
- Text-to-Speech implementation
- SpeechRecognizer / speech input implementation
- microphone handling
- permission handling
- TalkBack detection
- accessibility APIs
- content descriptions
- accessibility semantics
- focus handling
- live regions
- announcements
- quiz implementation
- quiz navigation
- lesson playback
- pause/resume logic
- timers
- state management
- lifecycle handling
- background/foreground behavior
- audio focus handling
- MediaPlayer/ExoPlayer/Media3/etc., whichever is actually being used
- coroutines
- Flow/StateFlow/LiveData
- Compose accessibility semantics if Compose is used
- XML accessibility properties if XML layouts are used
- network-dependent voice functionality
- error handling
- loading states
- microphone state management
- any "echo guard", speech detection, silence detection, cooldown, or debounce logic
- app-level notifications/announcements
- screen reader related code
- AndroidManifest.xml
- Gradle configuration
- dependencies relevant to accessibility/audio/voice
- tests
- existing documentation
- TODOs and comments related to accessibility

Search the repository for relevant concepts and keywords such as:

```text
TalkBack
AccessibilityManager
AccessibilityService
isTouchExplorationEnabled
contentDescription
semantics
liveRegion
focus
requestFocus
clearFocus
announceForAccessibility
TYPE_VIEW_ACCESSIBILITY_FOCUSED
TYPE_VIEW_FOCUSED
TTS
TextToSpeech
SpeechRecognizer
RecognizerIntent
microphone
AudioRecord
audio focus
MediaPlayer
ExoPlayer
Media3
pause
resume
play
stop
voice
echo
cooldown
debounce
quiz
next
answer
selected
checked
lesson
announcement
```

Also inspect code that does not explicitly mention TalkBack but could affect it.

For example:

- UI recomposition
- screen transitions
- focus changes
- visibility changes
- audio focus
- lifecycle callbacks
- delayed callbacks
- timers
- coroutines
- state restoration

---

# PHASE 2 — CREATE AN ARCHITECTURE MAP BEFORE MODIFYING CODE

After inspecting the codebase, document internally (and in your response/report) how the current system works.

At minimum identify:

### A. TalkBack detection

How does AudioLearner currently determine that TalkBack/accessibility interaction is enabled?

Determine:

- What Android API is being used?
- Is it detecting TalkBack specifically or merely touch exploration/accessibility?
- Is the detection reliable?
- Where is the result stored?
- Is it reactive if the user turns TalkBack on/off while the app is running?
- Which parts of the application depend on this detection?

Do not replace the current implementation merely because another method exists.

Determine what the application actually needs to detect.

---

### B. Audio architecture

Map every source of audio.

For example:

```text
Lesson audio
      ↓
Audio player

App TTS
      ↓
TextToSpeech

TalkBack
      ↓
Android accessibility service

Voice input
      ↓
Microphone
      ↓
Speech recognition
```

Determine how these systems interact.

Identify potential conflicts between:

- TalkBack speech
- application TTS
- lesson audio
- microphone recording
- Android audio focus
- speech recognition
- playback state

---

### C. State architecture

Find the actual sources of truth for:

- lesson playing
- lesson paused
- lesson stopped
- TTS speaking
- microphone active
- microphone paused
- speech recognition active
- quiz question
- selected answer
- submitted answer
- next question
- loading
- errors

Identify situations where the UI displays a state that does not correspond to the actual underlying state.

---

# PHASE 3 — DEFINE TWO EXPLICIT INTERACTION MODES

Design the application around two valid modes:

## Mode 1 — TalkBack ON

This should be the **accessibility-first learning mode**.

TalkBack should be treated as the student's primary screen-reading mechanism.

The application should avoid unnecessarily duplicating information through its own TTS when TalkBack is already providing it.

The student should be able to:

- navigate the interface using TalkBack gestures
- hear meaningful labels
- understand the current screen
- move between controls
- answer quizzes
- move to the next question
- play/pause lessons
- activate voice input where available
- understand errors
- recover from failures

without confusing overlapping speech.

---

## Mode 2 — TalkBack OFF

The application should continue working normally.

Its own TTS/audio guidance can be used where intended.

Do not break the normal sighted/non-TalkBack experience while improving accessibility.

---

# PHASE 4 — QUIZ NAVIGATION WITH TALKBACK

Current bad experience:

> While attempting a quiz with TalkBack ON, tapping "Next Question" causes TalkBack to read the screen again from the top, including things such as the battery/status area, instead of naturally moving to the new question.

Investigate this deeply.

Determine exactly why this happens.

Possible causes to investigate include:

- accessibility focus being lost
- accessibility focus returning to the root
- screen recreation
- navigation recreation
- recomposition
- incorrect focus restoration
- replacing the entire view hierarchy
- changing semantics
- improper live-region usage
- announcing too much content
- incorrect accessibility traversal order
- focusable containers
- screen transition behavior

Do not assume one cause.

### Desired behavior

When the student activates:

**Next Question**

the experience should be approximately:

```text
Student activates Next Question
        ↓
New question becomes available
        ↓
TalkBack focus moves intentionally
        ↓
TalkBack announces the new question
        ↓
Student can immediately explore/select an answer
```

It should NOT become:

```text
Next Question
      ↓
entire screen recreated
      ↓
TalkBack loses context
      ↓
focus jumps to top/root
      ↓
status/battery/etc. is read
      ↓
student has to navigate again
```

Find the cleanest Android accessibility solution.

Consider whether the new question should be exposed through:

- accessibility focus
- a live region
- explicit focus request
- semantic changes
- a dedicated announcement

Use the approach that is technically appropriate for the actual UI architecture.

Avoid excessive announcements.

The student should hear **only what is necessary to understand the new question**.

---

# PHASE 5 — INVESTIGATE "GHOST" ANSWER SELECTION

Current bad experience:

> With TalkBack ON, sometimes an answer appears to be selected without the student intentionally double-tapping it. It may look as though a random answer has been selected automatically.

Treat this as a serious correctness issue.

Do not simply add delays until it "seems better."

Trace the complete event chain.

Determine whether selection could be caused by:

- accessibility focus being confused with activation
- `onFocus`
- `onClick`
- `onTouch`
- pointer events
- gesture detection
- Compose semantics
- recomposition
- state restoration
- delayed callbacks
- stale state
- multiple listeners
- accessibility actions
- keyboard events
- touch exploration
- automatic focus changes
- programmatic selection
- answer state being restored incorrectly

Important distinction:

> **TalkBack focusing an answer is NOT the same thing as selecting an answer.**

The student should be able to explore answers without accidentally submitting/selecting them.

### Desired principle

For quiz answers:

```text
TalkBack focus
      ≠
Answer selection
```

and:

```text
Double tap / explicit activation
      ↓
Select answer
```

unless there is a deliberate accessibility interaction that clearly represents activation.

Selection must never happen merely because an answer receives accessibility focus.

---

# PHASE 6 — INVESTIGATE TTS → MICROPHONE TIMING

Current bad experience:

> The application's text-to-speech sometimes has not finished speaking, but voice input activates immediately.

This creates an extremely bad learning experience because the microphone starts listening while the system/app is still speaking.

Investigate the current "echo guard" or equivalent mechanism.

Do not assume the echo guard is simply too aggressive.

Determine:

1. What currently starts microphone input?
2. What stops/pauses TTS?
3. What event is interpreted as "TTS finished"?
4. Is the TTS completion callback reliable?
5. Are there race conditions?
6. Are coroutines/callbacks overlapping?
7. Is there a fixed timeout?
8. Is the microphone activated before TTS completion?
9. Is Android audio focus involved?
10. Is TalkBack speech being mistaken for application TTS?
11. Is the system waiting for actual TTS completion or merely estimating it?

Investigate whether the application should use proper TTS lifecycle callbacks such as utterance completion rather than arbitrary delays.

### Desired behavior

When the application needs speech input:

```text
App needs to speak
      ↓
TTS speaks
      ↓
TTS genuinely finishes
      ↓
small intentional transition/safety window if necessary
      ↓
microphone activates
      ↓
student speaks
```

Not:

```text
TTS starts
      ↓
short timer
      ↓
microphone activates
      ↓
TTS is still speaking
      ↓
student's speech / TTS / TalkBack interfere
```

However, be careful:

**Do not simply make the delay extremely long.**

The goal is reliable synchronization with minimum unnecessary waiting.

---

# PHASE 7 — TALKBACK VS APPLICATION TTS

Current bad experience:

> With TalkBack ON, a student can double-tap to play a lesson, but the application's UI says the lesson is paused while TalkBack is reading it.

Then:

> Double-tapping again pauses TalkBack's speech and opens the application's TTS, producing noise and confusion.

This indicates that the application does not have a coherent model of the different audio systems.

Investigate this carefully.

Distinguish at least:

```text
Lesson audio
Application TTS
TalkBack speech
Microphone / speech recognition
```

These are not necessarily the same thing.

Do not create a fake "one audio state" if the systems have different ownership.

### Desired principle

When TalkBack is ON:

- Do not unnecessarily use application TTS to repeat text that TalkBack is already reading.
- Do not let lesson controls accidentally interfere with TalkBack's accessibility speech.
- Do not make the application display "paused" simply because TalkBack is speaking.
- Do not assume that a TalkBack announcement means the lesson player is paused.
- Do not hijack audio focus unnecessarily.
- Avoid two speech systems talking simultaneously.

Investigate whether lesson playback and accessibility speech should be coordinated through state, audio focus, or explicit interaction rules.

### Important

Do not blindly mute all application audio whenever TalkBack is enabled.

A blind learner still needs lesson audio.

The goal is **coordination**, not simply suppression.

---

# PHASE 8 — "MICROPHONE PAUSED" BUT SPEECH DOES NOT WORK

Current bad experience:

> The application says "Microphone paused, tap anywhere to speak," but after tapping, voice input does not activate or speech cannot be recognized.

Investigate the entire state transition.

Trace:

```text
microphone paused
        ↓
user taps
        ↓
what event occurs?
        ↓
what state changes?
        ↓
permission state?
        ↓
SpeechRecognizer?
        ↓
microphone?
        ↓
network?
        ↓
audio focus?
        ↓
recognition callback?
```

Look for cases where the UI claims:

```text
ready to speak
```

while the actual recognizer is:

```text
inactive / destroyed / unavailable / waiting / failed
```

The visible/accessibility state must correspond to the actual recognizer state.

Define explicit states if necessary.

For example:

```text
IDLE
PREPARING
LISTENING
PROCESSING
PAUSED
UNAVAILABLE
ERROR
```

Do not necessarily use these exact names; use an appropriate state model for the existing architecture.

---

# PHASE 9 — VOICE INPUT IS OPTIONAL, NOT THE ONLY ACCESS PATH

Voice input requires internet connectivity in our current design.

Therefore, the application must not make voice interaction the only way a blind student can operate the application.

The primary fallback should be:

> **TalkBack + predictable gestures + accessible controls**

A student should still be able to:

- navigate lessons
- start/stop playback
- pause/resume
- move through quizzes
- select answers
- submit answers
- move to another question
- understand feedback
- recover from errors

without speech recognition.

The design should gracefully communicate when voice input is unavailable because of:

- no internet
- microphone permission
- recognizer failure
- network timeout
- service unavailable

The user should never get trapped because voice recognition failed.

---

# PHASE 10 — GESTURE-FIRST ACCESSIBILITY

Investigate how the app behaves with standard TalkBack gestures.

Think from the perspective of a blind student who does not see the screen.

The interface should have a predictable accessibility traversal order.

For every important screen, ask:

1. What does TalkBack focus first?
2. Is that useful?
3. What does it focus next?
4. Is the order logical?
5. Are decorative elements being announced?
6. Are duplicate elements being announced?
7. Can the student identify the purpose of each control?
8. Is the current state announced?
9. Does activating the control produce a predictable result?
10. After the action, where does accessibility focus go?
11. Can the student continue without restarting navigation?

Do not optimize merely for automated accessibility checkers.

Optimize for actual blind students.

---

# PHASE 11 — SCREEN-BY-SCREEN ACCESSIBILITY AUDIT

Go through the application's important screens and audit them individually.

At minimum inspect:

- login
- registration/onboarding if present
- home/dashboard
- lesson list
- lesson details
- lesson playback
- quiz
- answer selection
- next question
- quiz completion/results
- voice interaction
- error states
- loading states
- settings
- logout
- any teacher/student-specific screens

For each screen, evaluate:

### Accessibility semantics

Are controls named correctly?

### Role

Does TalkBack understand whether something is:

- button
- checkbox
- radio option
- heading
- text
- progress indicator
- input field
- list item

?

### State

Does TalkBack know whether something is:

- selected
- checked
- disabled
- playing
- paused
- loading
- completed
- unavailable

?

### Traversal

Is the order logical?

### Activation

Does TalkBack's normal activation gesture trigger the intended action?

### Feedback

Does the student receive useful feedback after activation?

### Focus restoration

After an action, where does TalkBack go?

### Duplicate speech

Is the same information spoken by both:

- TalkBack
- application TTS
- lesson audio

?

---

# PHASE 12 — "HEY GOOGLE, OPEN AUDIOLEARNER"

We considered allowing a student to say:

> "Hey Google, Open AudioLearner"

However, in testing this depends on the Google/Gemini environment and may instead perform a web search or require internet connectivity.

Do not assume this is a reliable solution.

Investigate Android's supported mechanisms for launching an application through voice/accessibility.

Consider the distinction between:

- Google Assistant/Gemini
- Android App Actions
- launcher shortcuts
- accessibility services
- Android intents
- voice access
- device-level accessibility features

The requirement is:

> We want a practical way for a blind student to launch AudioLearner using voice where the Android device supports it, without making the application depend on web search.

Investigate what is realistically possible on modern Android.

If there is no reliable way for the application itself to guarantee a completely offline "Hey Google" command, say so clearly.

Do not implement a fake solution.

Prefer mechanisms that are:

- officially supported by Android
- predictable
- maintainable
- usable by blind students
- not dependent on web search
- not dependent on an undocumented Google/Gemini behavior

If an Android App Action, launcher capability, intent, or another supported mechanism is appropriate, determine how it should be implemented.

---

# PHASE 13 — TALKBACK DETECTION SHOULD NOT BECOME A SINGLE GLOBAL SWITCH

Be careful with logic such as:

```text
if TalkBack:
    do X
else:
    do Y
```

Some behavior may need to differ based on accessibility state, but do not create a completely separate application that becomes difficult to maintain.

Prefer shared application behavior with accessibility-aware differences where they genuinely improve usability.

For example:

```text
same lesson
same quiz
same data
same core actions
        ↓
different presentation / feedback
depending on accessibility context
```

---

# PHASE 14 — SEARCH FOR ROOT CAUSES, NOT SYMPTOM PATCHES

Do not solve problems by adding arbitrary:

```text
delay(1000)
delay(2000)
delay(3000)
```

unless there is a demonstrated reason for the delay.

Do not add:

- random debounces
- arbitrary sleeps
- duplicate callbacks
- forced screen reloads
- excessive announcements
- global audio muting
- unnecessary state resets

just to hide symptoms.

Every important fix should have a technical reason.

Prefer:

- correct lifecycle handling
- explicit state machines
- proper callbacks
- correct accessibility semantics
- accessibility focus management
- correct audio focus handling
- proper synchronization
- single sources of truth
- idempotent actions
- cancellation of stale operations
- predictable state transitions

---

# PHASE 15 — PREVENT RACE CONDITIONS

Pay special attention to asynchronous interactions.

Potential races include:

```text
TTS finishes
       +
microphone starts
```

at the same time as:

```text
TalkBack speaks
```

or:

```text
quiz question changes
       +
UI recomposes
       +
accessibility focus changes
```

or:

```text
student taps
       +
old coroutine completes
       +
state changes unexpectedly
```

Look for these systematically.

Where appropriate, make operations:

- cancellable
- serialized
- state-aware
- idempotent

An old asynchronous operation should not be allowed to overwrite newer user intent.

---

# PHASE 16 — DESIGN A CLEAR AUDIO PRIORITY MODEL

Investigate whether AudioLearner needs an explicit audio priority policy.

A possible conceptual hierarchy is:

```text
User interaction / accessibility feedback
                ↓
Required learning audio
                ↓
Application TTS
                ↓
Voice recognition
```

But do NOT blindly implement this exact hierarchy.

Determine the appropriate priority from Android's actual audio/accessibility behavior and the learning requirements.

The important requirement is:

> The student should never experience multiple speech systems competing unnecessarily.

Document the resulting policy.

---

# PHASE 17 — ACCESSIBILITY FEEDBACK SHOULD BE CONCISE

For TalkBack users, avoid reading the same information multiple times.

Bad:

```text
"Question 3."
"Question 3."
"Which of the following..."
"Which of the following..."
```

Better:

```text
"Question 3 of 10. Which of the following...?"
```

Likewise, after an answer:

```text
"Correct."
```

rather than reading the entire screen again unless necessary.

Accessibility feedback should provide enough information for orientation without creating audio overload.

---

# PHASE 18 — DO NOT BREAK NON-TALKBACK USERS

After implementing accessibility improvements, verify that TalkBack OFF remains good.

Check:

- normal touch interaction
- visual state
- buttons
- audio playback
- TTS
- microphone
- quiz interaction
- navigation
- loading
- errors

Do not make the normal interface worse simply to fix accessibility.

---

# PHASE 19 — TESTING PLAN

Create a practical testing matrix.

At minimum:

| Scenario | TalkBack | Internet | Expected result |
|---|---|---|---|
| Browse lessons | ON | OFF | Works using gestures |
| Play lesson | ON | OFF | Lesson audio works without speech conflict |
| Pause lesson | ON | OFF | Lesson pauses; TalkBack remains usable |
| Quiz | ON | OFF | Student can navigate and answer |
| Next question | ON | OFF | New question is announced/focused correctly |
| Answer exploration | ON | OFF | Focus does not select answer |
| Answer activation | ON | OFF | Explicit activation selects answer |
| Voice input | ON | ON | TTS completes before listening |
| Voice input unavailable | ON | OFF | Student gets clear fallback |
| Microphone resume | ON | ON | Listening actually starts |
| Launch app | ON | OFF | Evaluate supported voice/launcher options |
| Normal use | OFF | OFF | Core app remains functional |
| Normal use | OFF | ON | Full intended functionality works |

Add additional cases where useful.

---

# PHASE 20 — USE REALISTIC TALKBACK TESTING

Do not rely only on unit tests.

Where possible, test with:

- TalkBack enabled
- touch exploration enabled
- swipe right/left navigation
- double-tap activation
- back gesture/button
- actual Android device
- slow network
- no network
- microphone permission denied
- microphone permission granted
- TTS enabled
- different TTS engines if practical

Pay special attention to low-end Android devices because AudioLearner is intended for students who may not have high-end phones.

---

# PHASE 21 — PERFORMANCE

Accessibility improvements must not make the app unnecessarily heavy.

Check for:

- excessive recomposition
- repeated TTS creation
- repeated recognizer creation
- memory leaks
- listeners not being removed
- lifecycle leaks
- unnecessary accessibility announcements
- repeated audio initialization
- long blocking operations on the main thread

Do not solve accessibility by creating expensive background behavior.

---

# PHASE 22 — IMPLEMENTATION STRATEGY

After investigation:

1. Identify root causes.
2. Group problems by underlying cause.
3. Explain which fixes solve multiple symptoms.
4. Implement the smallest clean architectural changes necessary.
5. Avoid duplicated logic.
6. Preserve existing functionality.
7. Add or update tests where practical.
8. Verify TalkBack OFF behavior.
9. Verify TalkBack ON behavior.
10. Review the final changes for regressions.

Do not make large unrelated refactors.

---

# PHASE 23 — DOCUMENT IMPORTANT DECISIONS

For each major accessibility/audio change, explain:

### Problem

What was happening?

### Root cause

Why was it happening?

### Fix

What was changed?

### Why this approach?

Why is this preferable to simpler alternatives?

### TalkBack behavior

How does this improve the blind student's experience?

### Normal behavior

What happens when TalkBack is OFF?

### Risks

What could still go wrong?

This is important because the project is being developed and learned from, not just patched until it appears to work.

---

# FINAL ACCEPTANCE CRITERIA

Do not consider the task complete merely because the application compiles.

The following should be true:

## TalkBack ON

- Navigation is predictable.
- TalkBack focus is meaningful.
- Focus does not randomly jump to the top of the screen.
- New quiz questions are announced naturally.
- Merely focusing an answer does not select it.
- Explicit activation selects the answer.
- TTS and TalkBack do not unnecessarily speak over each other.
- Lesson audio remains usable.
- Play/pause state is accurate.
- Microphone state matches actual recognizer state.
- TTS completion and microphone activation are properly synchronized.
- Voice failure does not trap the student.
- Gesture-based interaction remains fully usable.
- Error messages are understandable.
- Feedback is concise.
- The student can complete the major learning flow without relying on voice input.

## TalkBack OFF

- Existing normal interaction continues working.
- Lesson playback works.
- TTS works where intended.
- Voice input works where network conditions allow it.
- Quiz interaction works.
- Visual UI states remain correct.
- No accessibility-specific fix creates unexpected normal-mode behavior.

---

# VERY IMPORTANT FINAL INSTRUCTION

Before changing anything, **inspect the whole relevant codebase and understand the current implementation**.

Do not guess.

Do not rewrite working systems unnecessarily.

Do not simply implement the suggestions in this document if the existing architecture shows a better solution.

The goal is not:

> "Make the reported bugs disappear."

The goal is:

> **Make AudioLearner genuinely easy and predictable for a blind student to learn with, with TalkBack treated as a primary interaction environment while preserving a good experience when TalkBack is OFF.**

Think from the student's perspective:

> "I cannot see the screen. I am listening. I need to know where I am, what is happening, what I can do next, and whether the action I just performed actually worked."

Every accessibility decision should make that experience clearer, calmer, and more predictable.

---

# DELIVERABLE

After investigation and implementation, provide a concise engineering report containing:

1. **Current architecture discovered**
2. **Accessibility/audio problems found**
3. **Root cause of each major problem**
4. **Changes implemented**
5. **Files changed**
6. **Why each important change was made**
7. **TalkBack ON behavior after changes**
8. **TalkBack OFF behavior after changes**
9. **Testing performed**
10. **Known limitations**
11. **Recommended future improvements**

Do not claim something was tested if it was not actually tested.

If a requested behavior is impossible or unreliable because of Android, TalkBack, Google Assistant/Gemini, device limitations, or network requirements, state that clearly and explain the closest reliable alternative.