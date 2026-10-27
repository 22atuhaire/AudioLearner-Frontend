import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audioapp/features/student/student_login_screen.dart'
    show kActiveStudentIdKey;
import 'package:audioapp/shared/services/accessibility_service.dart';
import 'package:audioapp/shared/services/providers.dart';
import 'package:audioapp/shared/services/stt_service.dart';
import 'package:audioapp/shared/services/tts_service.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _navigated = false;

  // Captured while `ref` is valid (initState). Using `ref` inside dispose()
  // throws "Cannot use ref after the widget was disposed" and, during a
  // teardown triggered by the screen locking or fast navigation, corrupts
  // the widget-tree finalization badly enough to restart the whole app.
  late final SttService _stt;
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _stt = ref.read(sttServiceProvider);
    _tts = ref.read(ttsServiceProvider);
    // Wake the free-tier backend now, in the background — by the time a
    // student reaches "join class" or lesson sync, the 30-60 second cold
    // start has already happened invisibly instead of in their face.
    unawaited(ref.read(backendApiServiceProvider).warmUp());
    Future<void>(() async {
      await ref.read(ttsInitProvider.future);
      if (!mounted) return;

      // Resume straight into learning for a student who has used this phone
      // before. Without this, every launch asks "student or teacher?" and
      // then "say your name" again — a toll a sighted user never pays,
      // charged to the student least able to pay it. It is also what makes
      // "Hey Google, open AudioLearner" genuinely useful: the student lands
      // in their lessons, speaking, instead of on a menu.
      if (await _resumeReturningStudent()) return;
      if (await _resumeReturningTeacher()) return;

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      const welcome =
          'Welcome to AudioLearner. Say student to continue as a student, '
          'or say teacher to continue as a teacher. You can also tap the '
          'bottom of the screen for student, or the teacher button at the '
          'top right.';
      // Let TalkBack speak this if it is running, rather than talking over it.
      if (AccessibilityMode.isScreenReaderActive) {
        AccessibilityMode.announce(
          'Welcome to Audio Learner. Double tap Student at the bottom of the screen to start learning, or double tap Teacher at the top right.',
        );
        return;
      }

      await ref.read(ttsServiceProvider).speakAndWait(welcome);
      if (mounted) unawaited(_listenForRole());
    });
  }

  /// Sends a previously signed-in teacher straight to the dashboard.
  ///
  /// Teacher accounts use the same durable Drift row and persisted signed-in
  /// id as the teacher access screen. Checking here avoids making a returning
  /// teacher repeat account creation just because the app was launched from
  /// the role-selection route.
  Future<bool> _resumeReturningTeacher() async {
    try {
      final link = ref.read(backendLinkServiceProvider);
      final teacherId = await link.getSignedInTeacherId();
      if (teacherId == null || !mounted) return false;

      final teacher = await ref
          .read(appDatabaseProvider)
          .teacherDao
          .getTeacherById(teacherId);
      if (teacher == null || !mounted) {
        if (teacher == null) await link.clearSignedInTeacher();
        return false;
      }

      _navigated = true;
      final greeting =
          'Welcome back, ${teacher.name}. Opening your teacher dashboard.';
      if (AccessibilityMode.isScreenReaderActive) {
        AccessibilityMode.announce(greeting);
      } else {
        unawaited(ref.read(ttsServiceProvider).speak(greeting));
      }
      ref.read(currentTeacherProvider.notifier).state = teacher;
      if (!mounted) return false;
      context.go('/teacher/dashboard');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends a previously signed-in student straight to the learning hub.
  ///
  /// Returns true when it navigated, so the caller skips the role prompt.
  /// Any failure falls through to the normal flow — a student who cannot be
  /// resumed must still be able to choose a role.
  Future<bool> _resumeReturningStudent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt(kActiveStudentIdKey);
      if (studentId == null || !mounted) return false;

      // Confirm the row still exists — app data may have been cleared, and
      // resuming into a hub with no student would strand them silently.
      final student = await ref
          .read(appDatabaseProvider)
          .studentDao
          .getStudentById(studentId);
      if (student == null || !mounted) return false;

      _navigated = true;
      final greeting = 'Welcome back, ${student.name}. Opening your lessons.';
      if (AccessibilityMode.isScreenReaderActive) {
        AccessibilityMode.announce(greeting);
      } else {
        unawaited(ref.read(ttsServiceProvider).speak(greeting));
      }
      if (!mounted) return false;
      context.go('/student/home');
      return true;
    } catch (_) {
      return false; // never block the normal path
    }
  }

  Future<void> _speak(String text) async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(text);
  }

  // Listening windows opened since the last request, and whether one is
  // open or opening now.
  int _roleWindows = 0;
  static const int _maxRoleWindows = 3;
  bool _roleListening = false;

  /// Voice-first role pick: listens for "student" or "teacher" and navigates
  /// accordingly. Re-listens on silence a bounded number of times (once per
  /// request under TalkBack). The tap zones below remain fully functional as a
  /// fallback.
  ///
  /// It used to re-listen forever. Under TalkBack, one press of "Say student
  /// or teacher" left the recognizer starting and stopping in the background
  /// — chiming, holding the microphone and the phone's main thread — while the
  /// student tried to use TalkBack. A repeat press while it is already
  /// listening is ignored instead of starting a second session.
  Future<void> _listenForRole({bool fresh = true}) async {
    if (!mounted || _navigated) return;
    if (fresh) {
      if (_roleListening) return;
      _roleWindows = 0;
    }
    _roleListening = true;

    final stt = ref.read(sttServiceProvider);
    final ready = await stt.initialize();
    if (!ready || !mounted || _navigated) {
      _roleListening = false;
      return;
    }
    _roleWindows++;

    // The cue marks the microphone opening; it must not delay it.
    unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
    unawaited(SystemSound.play(SystemSoundType.click).catchError((_) {}));

    var handled = false;
    void match(String words) {
      if (handled || _navigated) return;
      final command = words.toLowerCase();
      if (command.contains('student') || command.contains('learner')) {
        handled = true;
        _navigated = true;
        unawaited(stt.stopListening());
        if (AccessibilityMode.isScreenReaderActive) {
          AccessibilityMode.announce('Student selected. Opening student login.');
        } else {
          _speak('Student selected. Opening the learner screen.');
        }
        context.go('/student/pin');
      } else if (command.contains('teacher')) {
        handled = true;
        _navigated = true;
        unawaited(stt.stopListening());
        if (AccessibilityMode.isScreenReaderActive) {
          AccessibilityMode.announce('Teacher selected. Opening teacher sign in.');
        } else {
          _speak('Teacher selected. Opening teacher sign in.');
        }
        context.push('/teacher/pin');
      }
    }

    final started = await stt.startListening(
      // Single-keyword pick: matching on partials keeps the response instant,
      // while the final result acts as a safety net for slower recognisers.
      onPartial: match,
      onResult: match,
      onDone: () {
        _roleListening = false;
        if (handled || _navigated || !mounted) return;
        handled = true;
        if (AccessibilityMode.isScreenReaderActive ||
            _roleWindows >= _maxRoleWindows) {
          return;
        }
        unawaited(_listenForRole(fresh: false));
      },
      // An engine failure (no internet, busy, no permission) will not fix
      // itself by retrying at once; the buttons are still there.
      onError: (_) => _roleListening = false,
    );
    if (!started) _roleListening = false;
  }

  void _openStudent() {
    _navigated = true;
    unawaited(ref.read(sttServiceProvider).stopListening());
    if (AccessibilityMode.isScreenReaderActive) {
      AccessibilityMode.announce('Student selected. Opening the learner screen.');
    } else {
      _speak('Student selected. Opening the learner screen.');
    }
    context.go('/student/pin');
  }

  void _openTeacher() {
    // Stop the background voice-command loop
    _navigated = true;
    unawaited(ref.read(sttServiceProvider).stopListening());
    context.push('/teacher/pin');
  }

  @override
  void dispose() {
    _stt.stopListening();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBF2FF),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Not a TalkBack target: it would be an invisible, unlabelled button
          // covering the screen. The three controls below are the interface.
          excludeFromSemantics: true,
          onTap: () {
            if (!_navigated) {
              unawaited(_listenForRole());
            }
          },
          child: Stack(
            children: [
            // ── Main content area with welcome message ───────────────────
            const SafeArea(
              child: SizedBox.expand(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        size: 72,
                        color: Color(0xFF1A56DB),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Audio Learning\nPlatform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A56DB),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Top-left Voice Button (accessible for TalkBack & voice) ───
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                // One clean TalkBack stop: "Say student or teacher, button,
                // double tap to speak after the tone" — not the label merged
                // with the button's own visible text.
                child: Semantics(
                  label: 'Say student or teacher',
                  button: true,
                  onTapHint: 'speak your choice after the tone',
                  onTap: () => unawaited(_listenForRole()),
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A56DB),
                      side: const BorderSide(
                        color: Color(0xFF1A56DB),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 20),
                    label: const Text(
                      'Say Role',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      unawaited(_listenForRole());
                    },
                  ),
                ),
              ),
            ),

            // ── Top-right Teacher Button ──────────────────────────────────
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Semantics(
                  label: 'Teacher',
                  button: true,
                  onTapHint: 'continue as a teacher',
                  onTap: _openTeacher,
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A56DB),
                      side: const BorderSide(
                        color: Color(0xFF1A56DB),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.person_rounded, size: 20),
                    label: const Text(
                      'Teacher',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _openTeacher,
                  ),
                ),
              ),
            ),

            // ── Accessible bottom zone for students ─────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 200,
              child: Semantics(
                button: true,
                label: 'Student',
                onTapHint: 'start learning',
                onTap: _openStudent,
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openStudent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1A56DB).withValues(alpha: 0.1),
                        const Color(0xFF1A56DB).withValues(alpha: 0.25),
                      ],
                    ),
                    border: const Border(
                      top: BorderSide(
                        color: Color(0xFF1A56DB),
                        width: 3,
                      ),
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: Color(0xFF1A56DB),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Tap to Enter as Student',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A56DB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
          ],
        ),
      ),
      ),
    );
  }
}
