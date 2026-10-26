import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Screen-reader awareness for AudioLearner.
///
/// ## Why this exists
///
/// This app was built voice-first: it speaks with its own TTS engine and is
/// driven by custom gestures (swipe, double-tap, long-press, two-finger tap).
/// That design assumes the app owns the screen.
///
/// A blind student does not switch TalkBack on to use one app — TalkBack is
/// already on, permanently, because it is how they use the phone at all. And
/// TalkBack takes over touch input: it consumes swipes for its own
/// element-to-element navigation and turns a double-tap into "activate the
/// focused item". Our gesture handlers then never fire, while TalkBack's voice
/// talks over our TTS. Two voices, no working gestures — worst for exactly the
/// student the app is for.
///
/// So the app runs in one of two modes, decided by the platform:
///
/// * **Screen-reader mode** — TalkBack (or VoiceOver) is driving. Same lessons,
///   same quiz, same actions; only the presentation changes. Every action is a
///   real, labelled control TalkBack can reach. Interface feedback goes through
///   TalkBack (focus and announcements), never our TTS. The microphone opens
///   only when the student asks for it (push-to-talk), never on a timer.
///   Lesson reading still uses our TTS, because reading a whole lesson with
///   pacing, speed control and resume is the product — TalkBack would only
///   read what is focused.
///
/// * **Voice-first mode** — no screen reader. The original spoken loop and
///   gesture set take over, unchanged.
///
/// "Screen reader" here means Android's touch exploration is on
/// (`accessibleNavigation`). That is exactly the condition that matters: it is
/// what makes TalkBack own touch input and speech, so it is what makes our
/// gestures unreachable and our speech a second voice.
///
/// ## Audio policy
///
/// Four things can make sound. Who goes when:
///
/// 1. **TalkBack** speaks whatever the student touches or focuses. The app
///    never competes with it for interface feedback: under a screen reader the
///    app's own spoken prompts are replaced by focus moves and announcements.
/// 2. **Lesson audio** (our TTS) plays only after an explicit play, and keeps
///    playing until an explicit pause or navigation. If TalkBack speaks while
///    a lesson plays, Android ducks the lesson; the app never stops a lesson
///    because TalkBack spoke, and never shows "paused" for that reason.
///    Feedback about the lesson itself (a new speed) is spoken in the lesson's
///    own voice, in sequence, rather than announced over it.
/// 3. **App prompts** (our TTS) exist in voice-first mode only.
/// 4. **The microphone** opens only when our TTS is idle by the engine's own
///    completion signal (`TtsService.whenIdle`), never during lesson playback,
///    and under a screen reader only on the student's explicit request.
///    There is no API for knowing when TalkBack has finished speaking, so the
///    app never guesses: anything automatic would let the microphone transcribe
///    TalkBack reading the screen and act on it.
///
/// Nothing here asks the student to change their phone settings. The app
/// adapts to them, which is the whole point.
class AccessibilityMode {
  const AccessibilityMode({required this.screenReaderEnabled});

  /// True when TalkBack, VoiceOver or another assistive reader is active.
  final bool screenReaderEnabled;

  /// The app should speak its own interface announcements (screen names,
  /// instructions, prompts). False under a screen reader, which announces
  /// focused widgets itself — doubling it up produces overlapping speech.
  bool get shouldSpeakChrome => !screenReaderEnabled;

  /// The app should open the microphone by itself after it speaks.
  ///
  /// Never under a screen reader (see the audio policy above). Students use
  /// the Voice command button instead.
  bool get shouldAutoListen => !screenReaderEnabled;

  /// Show the on-screen control panel of real, labelled buttons.
  ///
  /// Essential under a screen reader, where the custom gestures cannot be
  /// relied on.
  bool get needsExplicitControls => screenReaderEnabled;

  /// The custom whole-screen gestures (swipes, double tap, long press,
  /// two-finger tap) should be active.
  ///
  /// Off under a screen reader: TalkBack passes some of its own gestures
  /// through to the app (a two-finger scroll arrives as a one-finger drag), so
  /// leaving them on let TalkBack navigation trigger app actions the student
  /// never asked for.
  bool get customGesturesEnabled => !screenReaderEnabled;

  /// Lesson and quiz *content* is spoken in both modes — it is the product.
  bool get shouldSpeakContent => true;

  static AccessibilityMode of(BuildContext context) => AccessibilityMode(
        screenReaderEnabled: MediaQuery.maybeOf(context)?.accessibleNavigation ??
            false,
      );

  /// Reads the flag without a [BuildContext] — usable from initState or a
  /// service. Prefer [of] inside build methods so the UI rebuilds when the
  /// student toggles TalkBack mid-session.
  static bool get isScreenReaderActive =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .accessibleNavigation;

  /// Speaks [message] through the screen reader without moving focus.
  ///
  /// Used for events that have no widget to focus — "Paused", "2 new lessons
  /// ready", a voice error. Prefer moving focus with [AccessibilityFocusTarget]
  /// when the event replaced what the student was touching: the screen reader
  /// then reads the new content itself, once, and the student can carry on
  /// swiping from there.
  ///
  /// [assertive] interrupts whatever TalkBack is saying. Use it for things the
  /// student must hear now (errors); keep routine confirmations polite so they
  /// queue behind TalkBack instead of cutting it off mid-word.
  static void announce(String message, {bool assertive = false}) {
    if (message.trim().isEmpty) return;
    // `SemanticsService.announce` is deprecated in favour of
    // `sendAnnouncement`, which takes a view so it can support multiple
    // windows. This app is single-window Android, the deprecated call still
    // works, and it is the API supported across the Flutter versions the
    // team builds with — so it is kept deliberately rather than churned.
    //
    // To migrate: check the signature in your SDK with
    //   flutter doctor -v              (find the SDK path)
    //   grep -n "sendAnnouncement" <sdk>/packages/flutter/lib/src/semantics/semantics_service.dart
    // then swap the call below. Behaviour is otherwise identical.
    // ignore: deprecated_member_use
    SemanticsService.announce(
      message,
      TextDirection.ltr,
      assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
    );
  }
}

/// Moves the screen reader's focus to [child] when asked to.
///
/// ## The problem it solves
///
/// When the control a TalkBack user just activated disappears — "Next
/// question" is replaced by the next question's answers, an answer is replaced
/// by its feedback, a subject card is replaced by the topic list — TalkBack's
/// focus has nowhere to go. It falls back to the top of the window and starts
/// reading the status bar, and the student has to swipe all the way back.
///
/// Wrapping the content that should be read next in this widget, and giving it
/// a fresh [request] at that moment, sends focus there once the new frame is
/// built. TalkBack then reads that content — once, as the focused item — and
/// the student's next swipe continues from it. This is Flutter's documented
/// use of [FocusSemanticEvent] ("the currently focused rendering object is
/// replaced by another"), the same mechanism the Navigator uses to restore
/// focus after a route is popped.
///
/// ## Usage
///
/// [child] must be a `Semantics(container: true, ...)` node, so the event lands
/// on exactly the node TalkBack should read.
///
/// Each value from [newRequest] moves focus at most once, to the first target
/// built with it. A target rebuilt later with the same value (a provider
/// refresh, say) does not steal focus back from wherever the student moved.
/// Targets that should not take focus get a null [request].
class AccessibilityFocusTarget extends StatefulWidget {
  const AccessibilityFocusTarget({
    super.key,
    required this.request,
    required this.child,
  });

  /// A value from [newRequest], or null to leave focus alone.
  final int? request;
  final Widget child;

  static int _issued = 0;
  static int _consumed = 0;

  /// Returns a new request token. Pass it to the target that should receive
  /// focus after the next frame.
  static int newRequest() => ++_issued;

  @override
  State<AccessibilityFocusTarget> createState() =>
      _AccessibilityFocusTargetState();
}

class _AccessibilityFocusTargetState extends State<AccessibilityFocusTarget> {
  @override
  void initState() {
    super.initState();
    _maybeFocus();
  }

  @override
  void didUpdateWidget(AccessibilityFocusTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request != oldWidget.request) _maybeFocus();
  }

  void _maybeFocus() {
    final request = widget.request;
    if (request == null || request <= AccessibilityFocusTarget._consumed) {
      return;
    }
    AccessibilityFocusTarget._consumed = request;
    // The semantics tree for this frame is sent to the platform before
    // post-frame callbacks run, so the node exists by the time focus is sent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !AccessibilityMode.isScreenReaderActive) return;
      context.findRenderObject()?.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A large, clearly labelled action button for the accessible control panel.
///
/// Minimum 56dp of height and a real [Semantics] button role, so TalkBack
/// announces "<label>, button" and activates it with the standard double-tap
/// its users already know — no app-specific gesture to learn.
class AccessibleActionButton extends StatelessWidget {
  const AccessibleActionButton({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPressed,
    this.background = const Color(0xFF032A5F),
    this.foreground = Colors.white,
  });

  final String label;

  /// What activating the button does, as a verb phrase ("move to the next
  /// subject"). TalkBack speaks it as "double-tap to <hint>" in place of its
  /// generic "double-tap to activate", so it adds meaning without adding a
  /// second "double tap" sentence.
  final String hint;
  final IconData icon;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTapHint: hint,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 96),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
