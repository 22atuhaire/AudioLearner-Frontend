### First Instructions

# AudioLearner — Improve TalkBack Double-Tap Responsiveness

The previous accessibility improvements have made AudioLearner better for blind students, but an important usability problem remains.

**Problem:** When TalkBack is ON, double-tapping a button or command sometimes takes too long to trigger its action. The student may have to double-tap repeatedly before the application responds. I have experienced this even without an internet connection, so do not assume network latency is the cause.

## Your task

Investigate the existing implementation and identify the root cause of delayed or missed TalkBack activations.

Pay particular attention to:

- Click handlers, touch listeners, gesture detection, and accessibility semantics.
- Duplicate event handling, debouncing, throttling, and unnecessary delays.
- UI state updates, recomposition, coroutines, and main-thread blocking.
- Whether TalkBack activation triggers the intended action exactly once.
- Whether buttons become temporarily disabled or remain in loading/busy states unnecessarily.
- Whether microphone, TTS, or other background operations interfere with unrelated button interactions.

## Expected improvements

1. Make standard TalkBack double-tap activation respond promptly and reliably.
2. Ensure one intentional activation triggers exactly one action.
3. Prevent missed taps, duplicate actions, and accidental repeated submissions.
4. Provide immediate, appropriate feedback when an action starts, without falsely indicating completion.
5. Preserve correct TalkBack focus, gesture navigation, and existing accessibility improvements.
6. Ensure the application remains responsive with and without internet, and does not regress when TalkBack is OFF.

Do not solve this by simply removing all debouncing, adding arbitrary delays, or rewriting working components. Distinguish genuine Android/TalkBack gesture-recognition delays from delays introduced by our own application code.

**Implement the necessary fixes**, add or update tests where practical, and verify the results on an Android device with TalkBack enabled.

Finally, report the root cause, files changed, fixes implemented, and any remaining limitations. Do not claim device testing was performed if it was not.

### Second Instructions

# AudioLearner — Offline Speech Recognition

We have already completed the larger TalkBack/accessibility investigation. Do NOT repeat the previous full codebase audit.

Now focus specifically on **voice input and offline speech recognition**.

AudioLearner currently uses voice input that generally requires internet connectivity. We want to determine whether we can support voice input without internet when the Android device has Google's/on-device speech recognition language pack installed.

Investigate the existing `SpeechRecognizer` implementation and determine:

1. Whether AudioLearner can use Android's **on-device speech recognizer**.
2. Whether the current implementation can detect if on-device recognition is available.
3. Whether we can use `SpeechRecognizer.createOnDeviceSpeechRecognizer()` where supported.
4. How to determine whether the required language is actually available offline.
5. What happens when:
   - internet is available + on-device recognition available
   - internet is available + on-device recognition unavailable
   - internet is unavailable + on-device recognition available
   - internet is unavailable + on-device recognition unavailable
6. Whether the Google offline speech language pack is actually usable by our application's `SpeechRecognizer`, rather than only by Google Assistant/Voice Access.
7. Whether Android/Samsung limitations affect this on our target devices.

### Desired behavior

Prefer this strategy:

```text
Voice input requested
        ↓
Can on-device recognition be used?
        ↓
     YES → use on-device recognition
        ↓
     NO
        ↓
Is network recognition available?
        ↓
     YES → use network recognition
        ↓
     NO
        ↓
Give the student a clear accessible fallback
```

Do not assume that installing an offline Google speech pack automatically makes the application's current recognizer offline.

Check the actual Android APIs and our existing implementation.

### Implementation

If on-device recognition is supported by our target Android versions and can be integrated safely:

- implement it cleanly;
- preserve the existing online fallback;
- avoid breaking TalkBack;
- make microphone/TTS synchronization continue working;
- clearly expose the actual recognition state to the user;
- avoid unnecessary delays or duplicated speech.

If the device/API cannot reliably guarantee offline recognition, **do not fake or force it**. Explain the limitation and recommend the most reliable architecture.

### Deliverable

After investigating, give me:

- what our current implementation does;
- whether offline recognition is possible;
- the exact Android API/mechanism to use;
- files that need changing;
- the implementation;
- how to test it with internet OFF;
- any Android/Samsung limitations.