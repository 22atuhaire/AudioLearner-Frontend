# AudioLearner: Honest Limitations and Practical Workarounds

AudioLearner is designed to work offline and to support blind learners, but it
cannot guarantee perfect speech recognition, instant responses, or uninterrupted
cloud synchronization. The following are realistic difficulties to explain
during demonstrations and deployment.

## Known difficulties

| Area | Honest limitation | Practical way to cope |
|---|---|---|
| Student name recognition | **Moderate risk.** Speech recognition can mishear names, especially unfamiliar names, accents, or quiet speech. | The student listens to the result, then accepts it or retries. Keep typing available as a fallback. |
| Class-code recognition | **High risk.** Short codes such as `WU74` are difficult because letters and digits sound alike, and speech services may return only part of a code. | Prefer typing when possible. Speak slowly, use the displayed format, and retry or ask a teacher to confirm the code. |
| TalkBack response time | **Variable delay.** TalkBack, text-to-speech, speech recognition, and low-end phones share limited audio and processing resources. Network calls and recognizer finalization can add more delay. | Wait for the current announcement to finish, swipe to the intended control, and double-tap anywhere to activate the focused control. Avoid repeated taps while waiting. |
| Internet and server response | **Unreliable on poor networks.** A request may succeed on the server while the phone times out, or the backend may take time to wake up. | Keep the phone connected until completion, retry using the same account flow, and refresh subjects after connectivity returns. Do not assume a `200` response means that lessons are ready. |
| Teacher content availability | **Not immediate.** A note may exist but still have no approved questions, so it will not yet be useful to students. | Teachers must review and approve generated questions. Students should refresh after approval and synchronization. |
| Question generation | **Not perfect.** Generated questions can be irrelevant, incomplete, or poorly phrased, especially for tables, bullet lists, or sparse notes. | Treat generation as an assistant, not an authority. Teacher approval remains required. |
| Offline versus cloud data | **Temporary differences are possible.** The phone can show cached lessons while the server contains newer or deleted content. | Refresh when online. Teachers should verify uploads and students should allow synchronization to finish. |
| Device and audio conditions | **Results vary by phone.** Microphone quality, Android version, permissions, background noise, battery state, and TalkBack settings affect recognition and timing. | Test the actual target device, grant microphone permission, reduce background noise, and keep a manual input path. |
| Duplicate registration risk | **Poor networks can cause repeated attempts.** The app and backend now reuse pending credentials and handle retries more safely, but accounts created during earlier failures may still need administrator cleanup. | Do not create a new student repeatedly after a timeout. Check the teacher dashboard before trying again. |

## What AudioLearner should not promise

- Perfect recognition of every name or spoken class code.
- Instant TalkBack announcements on every device or network.
- That every uploaded note is immediately visible to students.
- That generated questions are correct without teacher review.
- That offline data is always the newest server data.

The safest presentation message is: **AudioLearner reduces barriers and provides
accessible fallbacks, while teachers and students retain confirmation and
retry control for uncertain input.**
