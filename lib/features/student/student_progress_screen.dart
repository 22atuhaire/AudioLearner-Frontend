import 'dart:async';

import 'package:audioapp/features/student/student_login_screen.dart'
    show kActiveStudentIdKey;
import 'package:audioapp/shared/services/accessibility_service.dart';
import 'package:audioapp/shared/services/progress_summary_service.dart';
import 'package:audioapp/shared/services/providers.dart';
import 'package:audioapp/shared/services/stt_service.dart';
import 'package:audioapp/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice-first "My Progress" screen.
///
/// On open it loads the student's local progress and speaks a full summary
/// (per-subject + overall + light encouragement). The visual layout mirrors the
/// spoken content for low-vision students and sighted helpers — large text,
/// high contrast, no information that is only available visually.
///
/// Reachable two ways from the learning hub: the header progress button, and
/// the spoken command "my progress" / "how am I doing".
class StudentProgressScreen extends ConsumerStatefulWidget {
  const StudentProgressScreen({super.key});

  @override
  ConsumerState<StudentProgressScreen> createState() =>
      _StudentProgressScreenState();
}

class _StudentProgressScreenState extends ConsumerState<StudentProgressScreen> {
  ProgressSummary? _summary;
  bool _loading = true;

  // Under TalkBack the summary is not announced in one long breath: focus
  // moves to the overall card (see build) and the student swipes through the
  // rest at their own pace.
  int? _focusRequest;

  // Bounded listen loop so the student can leave by voice. Without this, a
  // blind student who opened progress (especially with nothing to report) hit a
  // dead end — the only way out was a sighted person tapping the back arrow.
  int _listenSession = 0;
  int _silentWindows = 0;
  static const int _maxSilentWindows = 5;

  // Spoken after every summary so leaving is always one short command away.
  static const String _navHint =
      ' To go back, say back, or double tap the screen. '
      'To hear this again, say repeat.';

  // Captured while `ref` is valid — using `ref` in dispose() throws and can
  // tear the whole app down during a screen-lock/navigation teardown.
  late final SttService _stt;
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _stt = ref.read(sttServiceProvider);
    _tts = ref.read(ttsServiceProvider);
    _load();
  }

  @override
  void dispose() {
    _listenSession++;
    _stt.stopListening();
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ref.read(ttsInitProvider.future);
      final db = ref.read(appDatabaseProvider);
      // The signed-in student, not simply the first one on the phone: on a
      // shared phone the first row is someone else.
      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getInt(kActiveStudentIdKey);
      final student = (activeId == null
              ? null
              : await db.studentDao.getStudentById(activeId)) ??
          await db.studentDao.getStudent();
      if (student == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        await _sayThenListen('No student profile found on this device yet.');
        return;
      }

      final summary = await ref
          .read(progressSummaryServiceProvider)
          .buildForStudent(student.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });

      if (AccessibilityMode.isScreenReaderActive) {
        setState(() => _focusRequest = AccessibilityFocusTarget.newRequest());
        return;
      }
      await _sayThenListen(buildSpokenProgressSummary(summary));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _sayThenListen(
          'Sorry, your progress could not be loaded right now.');
    }
  }

  /// Speaks [text] and how to leave, then opens a bounded listening window
  /// for "back" / "repeat" so the student is never trapped on this screen.
  ///
  /// Under TalkBack only [text] is announced: the voice and double-tap-the-
  /// screen instructions do not apply there, and the Back button is a normal
  /// control TalkBack reaches.
  Future<void> _sayThenListen(String text) async {
    if (AccessibilityMode.isScreenReaderActive) {
      AccessibilityMode.announce(text);
      return;
    }
    final session = ++_listenSession;
    await ref.read(sttServiceProvider).stopListening();
    if (!mounted || session != _listenSession) return;
    await ref.read(ttsServiceProvider).speakAndWait(text + _navHint);
    if (!mounted || session != _listenSession) return;
    _listenForCommand(session);
  }

  Future<void> _listenForCommand(int session) async {
    if (!mounted || session != _listenSession) return;
    final stt = ref.read(sttServiceProvider);
    final ready = await stt.initialize();
    if (!ready || !mounted || session != _listenSession) return;

    // Our own speech must be finished (engine completion) before listening.
    await _tts
        .whenIdle()
        .timeout(const Duration(seconds: 20), onTimeout: () {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || session != _listenSession) return;

    var handled = false;
    void act(String words) {
      if (handled || session != _listenSession) return;
      final c = words.toLowerCase();
      if (c.contains('back') ||
          c.contains('home') ||
          c.contains('return') ||
          c.contains('exit') ||
          c.contains('done') ||
          c.contains('learning') ||
          c.contains('subjects')) {
        handled = true;
        unawaited(stt.stopListening());
        _goBack();
      } else if (c.contains('repeat') || c.contains('again')) {
        handled = true;
        unawaited(stt.stopListening());
        _replay();
      }
    }

    await stt.startListening(
      onPartial: act,
      onResult: act,
      onDone: () {
        if (handled || session != _listenSession) return;
        handled = true;
        _silentWindows++;
        if (_silentWindows >= _maxSilentWindows) return; // go quiet
        _listenForCommand(session);
      },
    );
  }

  void _goBack() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student/home');
    }
  }

  void _replay() {
    _silentWindows = 0;
    final summary = _summary;
    final text = summary == null
        ? 'There is no progress to show yet.'
        : buildSpokenProgressSummary(summary);
    unawaited(_sayThenListen(text));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFEBF2FF),
        appBar: AppBar(
          title: const Text('My Progress'),
          backgroundColor: const Color(0xFF1A56DB),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: Semantics(
            button: true,
            label: 'Back to learning',
            hint: 'Double tap to return to learning hub',
            onTap: _goBack,
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to learning',
              onPressed: _goBack,
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Voice command',
              hint: 'Double tap to speak a command like back or repeat',
              onTap: () {
                _silentWindows = 0;
                _listenForCommand(++_listenSession);
              },
              excludeSemantics: true,
              child: IconButton(
                icon: const Icon(Icons.mic_rounded),
                tooltip: 'Voice command. Double tap to speak.',
                onPressed: () {
                  _silentWindows = 0;
                  _listenForCommand(++_listenSession);
                },
              ),
            ),
          ],
        ),
        // Single tap replays the summary; double tap leaves — both work without
        // sight, alongside the spoken "back" command.
        // (TalkBack never passes these taps on; there the Back button and
        // the cards themselves are the interface.)
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _replay,
          onDoubleTap: _goBack,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _summary == null
                  ? _message(AccessibilityMode.of(context).screenReaderEnabled
                      ? 'No progress to show yet.'
                      : 'No progress to show yet.\n\nDouble tap to go back.')
                  : _buildSummary(_summary!),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A56DB),
            ),
          ),
        ),
      );

  Widget _buildSummary(ProgressSummary s) {
    if (!s.hasAnyContent) {
      return _message(
          'No lessons yet. When your teacher adds lessons, your progress '
          'will appear here.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _overallCard(s),
        if (s.studyStreakDays >= 2) ...[
          const SizedBox(height: 12),
          _streakBanner(s.studyStreakDays),
        ],
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'By subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF123B7A),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...s.subjects.map(_subjectCard),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Tap anywhere to hear this again',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _overallCard(ProgressSummary s) {
    final pct = s.overallCompletionPercent.round();
    final acc = s.overallQuizAccuracyPercent;
    // One TalkBack stop for the whole card, read as a sentence, instead of
    // four fragments ("Overall completion", "43%", ...).
    return AccessibilityFocusTarget(
      request: _focusRequest,
      child: Semantics(
        container: true,
        label: 'Overall, ${s.completedLessons} of ${s.totalLessons} '
            'lesson${s.totalLessons == 1 ? '' : 's'} finished, $pct percent.'
            '${acc != null ? ' Quiz score ${acc.round()} percent.' : ''}',
        excludeSemantics: true,
        child: _overallCardBox(s, pct),
      ),
    );
  }

  Widget _overallCardBox(ProgressSummary s, int pct) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall completion',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$pct%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.completedLessons} of ${s.totalLessons} '
            'lesson${s.totalLessons == 1 ? '' : 's'} finished',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (s.overallQuizAccuracyPercent != null) ...[
            const SizedBox(height: 4),
            Text(
              'Quiz score ${s.overallQuizAccuracyPercent!.round()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ],
      ),
    );
  }

  Widget _streakBanner(int days) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C451)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFE8870C), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$days-day streak! Keep it going.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A5A00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(SubjectProgress subj) {
    final pct = subj.completionPercent.round();
    final acc = subj.quizAccuracyPercent;
    return Semantics(
      container: true,
      label: '${subj.subjectName}. ${subj.completedLessons} of '
          '${subj.totalLessons} lesson${subj.totalLessons == 1 ? '' : 's'} '
          'finished, $pct percent.'
          '${acc != null ? ' Quiz score ${acc.round()} percent.' : ''}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subj.subjectName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF123B7A),
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A56DB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: subj.totalLessons == 0 ? 0 : pct / 100,
                minHeight: 10,
                backgroundColor: const Color(0xFFE5EAF5),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${subj.completedLessons} of ${subj.totalLessons} '
              'lesson${subj.totalLessons == 1 ? '' : 's'}'
              '${subj.quizAccuracyPercent != null ? '  •  Quiz ${subj.quizAccuracyPercent!.round()}%' : ''}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
