import 'package:sqflite/sqflite.dart';

import '../core/day_key.dart';
import 'app_database.dart';
import 'models/focus_session.dart';
import 'models/habit.dart';

/// Streak + completion maths for a single habit, computed on read. The data
/// set is small (one row per habit per day) so this stays cheap.
class HabitProgress {
  const HabitProgress({
    required this.habit,
    required this.doneToday,
    required this.dueToday,
    required this.missedYesterday,
    required this.currentStreak,
    required this.bestStreak,
    required this.streakBeforeLapse,
    required this.completionsThisWeek,
    required this.last30,
  });

  final Habit habit;
  final bool doneToday;

  /// Whether the habit's schedule expects it today at all.
  final bool dueToday;

  /// Was due on the most recent prior due-day and was not ticked off.
  final bool missedYesterday;

  final int currentStreak;
  final int bestStreak;

  /// How long the streak was immediately before it lapsed. Zero when the
  /// streak is still alive - this is what tells "sad" apart from "never
  /// started".
  final int streakBeforeLapse;

  final int completionsThisWeek;

  /// Day key -> completed, for the last 30 days (oldest first).
  final Map<String, bool> last30;

  bool get weeklyTargetMet =>
      habit.schedule == HabitSchedule.weekly &&
      completionsThisWeek >= habit.targetPerWeek;

  /// True when a streak of 2+ is still alive but today is not ticked off -
  /// the cue for the mascot to look concerned.
  bool get streakAtRisk => currentStreak >= 2 && !doneToday;

  /// Due today, still not done, and the day is running out.
  bool overdueAt(DateTime now) =>
      dueToday && !doneToday && now.hour >= 18;

  /// Missed its last due day outright.
  bool get missed => missedYesterday && !doneToday;

  /// A streak of three or more ended within the last couple of days.
  bool get streakJustBroken => currentStreak == 0 && streakBeforeLapse >= 3;
}

class HabitRepository {
  HabitRepository(this._database);

  final AppDatabase _database;
  Database get _db => _database.db;

  Future<List<Habit>> allHabits({bool includeArchived = false}) async {
    final rows = await _db.query(
      'habits',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Habit.fromRow).toList();
  }

  Future<Habit?> byId(String id) async {
    final rows = await _db.query('habits', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Habit.fromRow(rows.first);
  }

  Future<void> upsert(Habit habit) => _db.insert(
        'habits',
        habit.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> delete(String id) =>
      _db.delete('habits', where: 'id = ?', whereArgs: [id]);

  Future<void> reorder(List<Habit> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update('habits', {'sort_order': i},
          where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> isDone(String habitId, String day) async {
    final rows = await _db.query(
      'habit_logs',
      where: 'habit_id = ? AND day = ?',
      whereArgs: [habitId, day],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setDone(
    String habitId,
    String day, {
    required bool done,
    String source = 'manual',
  }) async {
    if (done) {
      await _db.insert(
        'habit_logs',
        HabitLog(habitId: habitId, day: day, completedAt: DateTime.now(), source: source)
            .toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db.delete('habit_logs',
          where: 'habit_id = ? AND day = ?', whereArgs: [habitId, day]);
    }
  }

  Future<bool> toggle(String habitId, String day) async {
    final done = await isDone(habitId, day);
    await setDone(habitId, day, done: !done);
    return !done;
  }

  Future<Set<String>> completedDays(String habitId) async {
    final rows = await _db.query('habit_logs',
        columns: ['day'], where: 'habit_id = ?', whereArgs: [habitId]);
    return rows.map((r) => r['day'] as String).toSet();
  }

  /// Consecutive *due* days ending today (or yesterday, so a habit that has
  /// not been ticked yet today still shows the streak it is defending).
  int _streakFrom(Habit habit, Set<String> done, DateTime anchor) {
    var streak = 0;
    var cursor = DayKey.startOfDay(anchor);
    final created = DayKey.startOfDay(habit.createdAt);
    var guard = 0;
    while (!cursor.isBefore(created) && guard++ < 3650) {
      if (habit.isDueOn(cursor)) {
        if (done.contains(DayKey.of(cursor))) {
          streak++;
        } else {
          break;
        }
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _bestStreak(Habit habit, Set<String> done) {
    if (done.isEmpty) return 0;
    final days = done.map(DayKey.parse).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      if (prev == null) {
        run = 1;
      } else {
        var gapOnlyUndueDays = true;
        var cursor = prev.add(const Duration(days: 1));
        while (cursor.isBefore(d)) {
          if (habit.isDueOn(cursor)) {
            gapOnlyUndueDays = false;
            break;
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        run = gapOnlyUndueDays ? run + 1 : 1;
      }
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// The most recent day before [from] that this habit was actually due.
  DateTime? _previousDueDay(Habit habit, DateTime from) {
    var cursor = DayKey.startOfDay(from).subtract(const Duration(days: 1));
    final created = DayKey.startOfDay(habit.createdAt);
    var guard = 0;
    while (!cursor.isBefore(created) && guard++ < 60) {
      if (habit.isDueOn(cursor)) return cursor;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return null;
  }

  /// How long the streak ran immediately before it lapsed, measured back from
  /// the last missed due-day. Zero while the streak is still alive.
  int _streakBeforeLapse(Habit habit, Set<String> done, DateTime today) {
    final lastDue = _previousDueDay(habit, today);
    if (lastDue == null) return 0;
    if (done.contains(DayKey.of(lastDue))) return 0; // streak not broken
    final before = _previousDueDay(habit, lastDue);
    if (before == null) return 0;
    return _streakFrom(habit, done, before);
  }

  Future<HabitProgress> progressFor(Habit habit) async {
    final done = await completedDays(habit.id);
    final today = DateTime.now();
    final todayKey = DayKey.of(today);
    final doneToday = done.contains(todayKey);

    final lastDue = _previousDueDay(habit, today);
    final missedYesterday =
        lastDue != null && !done.contains(DayKey.of(lastDue));

    // If today is not done yet, measure the streak from yesterday so an
    // untouched morning does not read as "streak lost".
    final anchor = doneToday ? today : today.subtract(const Duration(days: 1));

    final weekStart = DayKey.startOfWeek(today);
    var thisWeek = 0;
    for (var i = 0; i < 7; i++) {
      if (done.contains(DayKey.of(weekStart.add(Duration(days: i))))) thisWeek++;
    }

    final last30 = <String, bool>{};
    for (var i = 29; i >= 0; i--) {
      final key = DayKey.of(today.subtract(Duration(days: i)));
      last30[key] = done.contains(key);
    }

    return HabitProgress(
      habit: habit,
      doneToday: doneToday,
      dueToday: habit.isDueOn(today),
      missedYesterday: missedYesterday,
      currentStreak: _streakFrom(habit, done, anchor),
      bestStreak: _bestStreak(habit, done),
      streakBeforeLapse: _streakBeforeLapse(habit, done, today),
      completionsThisWeek: thisWeek,
      last30: last30,
    );
  }

  Future<List<HabitProgress>> allProgress() async {
    final habits = await allHabits();
    return Future.wait(habits.map(progressFor));
  }

  /// Habit ids completed on [day] - used by the calendar detail panel.
  Future<Set<String>> completedOn(String day) async {
    final rows = await _db.query('habit_logs',
        columns: ['habit_id'], where: 'day = ?', whereArgs: [day]);
    return rows.map((r) => r['habit_id'] as String).toSet();
  }

  /// day -> number of habits ticked, for the heatmap.
  Future<Map<String, int>> completionCountsBetween(String from, String to) async {
    final rows = await _db.rawQuery(
      'SELECT day, COUNT(*) AS n FROM habit_logs WHERE day BETWEEN ? AND ? GROUP BY day',
      [from, to],
    );
    return {for (final r in rows) r['day'] as String: (r['n'] as int?) ?? 0};
  }
}
