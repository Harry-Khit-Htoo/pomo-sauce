import '../../core/day_key.dart';
import 'pomodoro_phase.dart';

/// One completed (or abandoned) interval, written to history when it ends.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.phase,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.actualSeconds,
    required this.completed,
    this.presetId,
    this.habitId,
  });

  final String id;
  final PomodoroPhase phase;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int actualSeconds;

  /// False when the user stopped early - abandoned intervals stay in history
  /// but never count towards streaks or totals.
  final bool completed;

  final String? presetId;

  /// Set when the user linked this focus session to a habit, which credits
  /// the habit for the day as soon as the session completes.
  final String? habitId;

  Duration get actual => Duration(seconds: actualSeconds);
  String get day => DayKey.of(startedAt);

  Map<String, Object?> toRow() => {
        'id': id,
        'phase': phase.name,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt.millisecondsSinceEpoch,
        'planned_seconds': plannedSeconds,
        'actual_seconds': actualSeconds,
        'completed': completed ? 1 : 0,
        'preset_id': presetId,
        'habit_id': habitId,
        'day': day,
      };

  factory FocusSession.fromRow(Map<String, Object?> row) => FocusSession(
        id: row['id'] as String,
        phase: PomodoroPhase.fromKey(row['phase'] as String?),
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        endedAt: DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
        plannedSeconds: (row['planned_seconds'] as int?) ?? 0,
        actualSeconds: (row['actual_seconds'] as int?) ?? 0,
        completed: (row['completed'] as int?) == 1,
        presetId: row['preset_id'] as String?,
        habitId: row['habit_id'] as String?,
      );
}

/// A habit ticked off on a given day.
class HabitLog {
  const HabitLog({
    required this.habitId,
    required this.day,
    required this.completedAt,
    this.source = 'manual',
  });

  final String habitId;
  final String day;
  final DateTime completedAt;

  /// `manual` when tapped, `pomodoro` when credited by a linked session.
  final String source;

  Map<String, Object?> toRow() => {
        'habit_id': habitId,
        'day': day,
        'completed_at': completedAt.millisecondsSinceEpoch,
        'source': source,
      };

  factory HabitLog.fromRow(Map<String, Object?> row) => HabitLog(
        habitId: row['habit_id'] as String,
        day: row['day'] as String,
        completedAt:
            DateTime.fromMillisecondsSinceEpoch(row['completed_at'] as int),
        source: (row['source'] as String?) ?? 'manual',
      );
}

/// Per-day totals used by the heatmap and the weekly chart.
class DayStats {
  const DayStats({
    required this.day,
    required this.focusSessions,
    required this.focusSeconds,
    required this.habitsCompleted,
  });

  final String day;
  final int focusSessions;
  final int focusSeconds;
  final int habitsCompleted;

  Duration get focusTime => Duration(seconds: focusSeconds);

  /// 0-4, the intensity bucket the heatmap paints.
  int get level {
    final score = focusSessions + habitsCompleted;
    if (score == 0) return 0;
    if (score <= 2) return 1;
    if (score <= 4) return 2;
    if (score <= 7) return 3;
    return 4;
  }
}
