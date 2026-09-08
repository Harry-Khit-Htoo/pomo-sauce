import '../data/habit_repository.dart';
import '../data/models/pomodoro_phase.dart';
import '../timer/pomodoro_state.dart';
import 'mascot_mood.dart';

/// Everything the mascot is allowed to react to, gathered in one place so the
/// rules below are readable and testable without a database.
class MoodSignals {
  const MoodSignals({
    required this.habits,
    required this.timer,
    required this.completedFocusToday,
    required this.totalCompletedSessions,
    this.justCompletedAt,
    this.onboarding = false,
    this.now,
  });

  final List<HabitProgress> habits;
  final PomodoroState timer;
  final int completedFocusToday;
  final int totalCompletedSessions;

  /// When the most recent interval finished, if it was recent enough to still
  /// be worth celebrating.
  final DateTime? justCompletedAt;

  final bool onboarding;
  final DateTime? now;

  DateTime get moment => now ?? DateTime.now();

  /// A completion counts as "just happened" for half a minute.
  bool get justCompleted {
    final at = justCompletedAt;
    if (at == null) return false;
    return moment.difference(at) < const Duration(seconds: 30);
  }

  static const milestones = {1, 5, 10, 25, 50, 100, 250, 500};
  bool get isMilestone => milestones.contains(totalCompletedSessions);
}

/// Picks the mascot's mood from real behaviour.
///
/// Order matters: the checks run from most urgent to most ambient, so a
/// celebration is never buried under an overdue habit, and an overdue habit
/// is never hidden behind an idle sway.
MascotMood selectMood(MoodSignals s) {
  if (s.onboarding) return MascotMood.welcoming;

  // 1. The moment something lands, react to it before anything else.
  if (s.justCompleted) {
    return s.isMilestone ? MascotMood.celebrating : MascotMood.happy;
  }

  // 2. A live timer owns the face while it runs.
  if (s.timer.status == TimerStatus.ringing) {
    return s.isMilestone ? MascotMood.celebrating : MascotMood.happy;
  }
  if (s.timer.status == TimerStatus.running) {
    return s.timer.phase == PomodoroPhase.focus
        ? MascotMood.neutral
        : MascotMood.sleepy;
  }

  // 3. A long streak still going is worth a look of pride.
  final bestLive = s.habits.fold<int>(
    0,
    (a, h) => h.currentStreak > a ? h.currentStreak : a,
  );
  if (bestLive >= 7 && s.habits.any((h) => h.doneToday)) {
    return MascotMood.celebrating;
  }

  // 4. Disappointment, but only for a habit genuinely missed - never for one
  //    the user simply has not got to yet this morning.
  if (s.habits.any((h) => h.missed)) return MascotMood.angry;
  if (s.habits.any((h) => h.overdueAt(s.moment))) return MascotMood.angry;

  // 5. A broken streak is sad, not angry: it invites a restart.
  if (s.habits.any((h) => h.streakJustBroken)) return MascotMood.sad;

  // 6. Something still due today, with time left on the clock.
  if (s.habits.any((h) => h.dueToday && !h.doneToday)) return MascotMood.alert;

  // 7. Everything done, or nothing scheduled.
  final allDone = s.habits.where((h) => h.dueToday).isNotEmpty &&
      s.habits.where((h) => h.dueToday).every((h) => h.doneToday);
  if (allDone || s.completedFocusToday > 0) return MascotMood.happy;

  return MascotMood.idle;
}
