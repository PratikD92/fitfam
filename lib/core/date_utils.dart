DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "2026-10-19"
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Next time (today or tomorrow) the given minute of the day occurs.
/// Values below 0 or above 1439 wrap, e.g. "30 min before 00:10".
DateTime nextOccurrence(DateTime now, int minutesOfDay) {
  var t = DateTime(now.year, now.month, now.day).add(Duration(minutes: minutesOfDay));
  if (!t.isAfter(now)) {
    t = DateTime(now.year, now.month, now.day + 1).add(Duration(minutes: minutesOfDay));
  }
  return t;
}

/// "in 2h 10m", "in 25m", "now"
String fmtIn(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins < 1) return 'now';
  final h = mins ~/ 60, m = mins % 60;
  if (h == 0) return 'in ${m}m';
  return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
}
