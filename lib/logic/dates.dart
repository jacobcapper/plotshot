DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Fractional days between two instants.
double daysBetween(DateTime from, DateTime to) =>
    to.difference(from).inMilliseconds / Duration.millisecondsPerDay;

/// Whole calendar days from [from] to [to], ignoring time of day and DST.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
