import 'package:sqflite/sqflite.dart';

import '../core/day_key.dart';
import 'app_database.dart';
import 'models/focus_session.dart';
import 'models/pomodoro_phase.dart';

class TodaySummary {
  const TodaySummary({
    required this.focusSessions,
    required this.focusTime,
    required this.habitsDone,
    required this.habitsTotal,
  });

  final int focusSessions;
  final Duration focusTime;
  final int habitsDone;
  final int habitsTotal;

  static const empty = TodaySummary(
    focusSessions: 0,
    focusTime: Duration.zero,
    habitsDone: 0,
    habitsTotal: 0,
  );
}

class SessionRepository {
  SessionRepository(this._database);

  final AppDatabase _database;
  Database get _db => _database.db;

  Future<void> insert(FocusSession session) => _db.insert(
        'sessions',
        session.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<FocusSession>> onDay(String day) async {
    final rows = await _db.query('sessions',
        where: 'day = ?', whereArgs: [day], orderBy: 'started_at DESC');
    return rows.map(FocusSession.fromRow).toList();
  }

  Future<List<FocusSession>> recent({int limit = 100}) async {
    final rows = await _db.query('sessions',
        orderBy: 'started_at DESC', limit: limit);
    return rows.map(FocusSession.fromRow).toList();
  }

  /// Completed focus intervals only - breaks and abandoned runs never count.
  Future<Map<String, DayStats>> statsBetween(
    String from,
    String to,
    Map<String, int> habitCounts,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT day, COUNT(*) AS n, SUM(actual_seconds) AS secs FROM sessions '
      'WHERE day BETWEEN ? AND ? AND phase = ? AND completed = 1 GROUP BY day',
      [from, to, PomodoroPhase.focus.name],
    );
    final byDay = <String, DayStats>{};
    for (final r in rows) {
      final day = r['day'] as String;
      byDay[day] = DayStats(
        day: day,
        focusSessions: (r['n'] as int?) ?? 0,
        focusSeconds: (r['secs'] as int?) ?? 0,
        habitsCompleted: habitCounts[day] ?? 0,
      );
    }
    // Days with habits but no focus sessions still belong on the heatmap.
    habitCounts.forEach((day, count) {
      byDay.putIfAbsent(
        day,
        () => DayStats(
          day: day,
          focusSessions: 0,
          focusSeconds: 0,
          habitsCompleted: count,
        ),
      );
    });
    return byDay;
  }

  Future<TodaySummary> todaySummary({
    required int habitsDone,
    required int habitsTotal,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n, SUM(actual_seconds) AS secs FROM sessions '
      'WHERE day = ? AND phase = ? AND completed = 1',
      [DayKey.today(), PomodoroPhase.focus.name],
    );
    final row = rows.first;
    return TodaySummary(
      focusSessions: (row['n'] as int?) ?? 0,
      focusTime: Duration(seconds: (row['secs'] as int?) ?? 0),
      habitsDone: habitsDone,
      habitsTotal: habitsTotal,
    );
  }

  /// Completed focus seconds for each of the last [days] days, oldest first.
  Future<List<({String day, int seconds, int count})>> lastDays(int days) async {
    final today = DateTime.now();
    final from = DayKey.of(today.subtract(Duration(days: days - 1)));
    final rows = await _db.rawQuery(
      'SELECT day, COUNT(*) AS n, SUM(actual_seconds) AS secs FROM sessions '
      'WHERE day >= ? AND phase = ? AND completed = 1 GROUP BY day',
      [from, PomodoroPhase.focus.name],
    );
    final map = {
      for (final r in rows)
        r['day'] as String: (
          seconds: (r['secs'] as int?) ?? 0,
          count: (r['n'] as int?) ?? 0,
        ),
    };
    return List.generate(days, (i) {
      final key = DayKey.of(today.subtract(Duration(days: days - 1 - i)));
      final v = map[key];
      return (day: key, seconds: v?.seconds ?? 0, count: v?.count ?? 0);
    });
  }

  Future<int> totalCompletedFocusSessions() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM sessions WHERE phase = ? AND completed = 1',
      [PomodoroPhase.focus.name],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> exportRows() =>
      _db.query('sessions', orderBy: 'started_at ASC');
}
