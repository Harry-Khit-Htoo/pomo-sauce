import 'package:intl/intl.dart';

/// Habit and session history is bucketed by *local calendar day*, stored as a
/// `yyyy-MM-dd` string so day comparisons never trip over time zones or DST.
abstract final class DayKey {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  static String of(DateTime dt) => _fmt.format(dt);

  static String today() => of(DateTime.now());

  static DateTime parse(String key) => DateTime.parse(key);

  static DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Whole days between two calendar days, ignoring the clock.
  static int daysBetween(DateTime a, DateTime b) =>
      startOfDay(b).difference(startOfDay(a)).inDays;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Monday-anchored start of the week containing [dt].
  static DateTime startOfWeek(DateTime dt) {
    final d = startOfDay(dt);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }
}
