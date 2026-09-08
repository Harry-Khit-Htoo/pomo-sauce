/// mm:ss, or h:mm:ss once the interval passes an hour.
String formatCountdown(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// "1h 25m" / "25m" / "40s" - for totals and history rows.
String formatDurationShort(Duration d) {
  if (d == Duration.zero) return '0m';
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String plural(int n, String one, [String? many]) =>
    n == 1 ? '$n $one' : '$n ${many ?? '${one}s'}';
