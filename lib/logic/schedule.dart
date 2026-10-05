import '../models/jab.dart';
import 'dates.dart';

enum DueState { notStarted, upcoming, dueToday, overdue }

class NextJabInfo {
  final DateTime? due;
  final DueState state;

  /// Days until due (negative when overdue).
  final int days;

  const NextJabInfo(this.due, this.state, this.days);

  String get label => switch (state) {
    DueState.notStarted => 'Log your first jab',
    DueState.dueToday => 'Due today',
    DueState.overdue =>
      days == -1 ? 'Due yesterday' : 'Overdue by ${-days} days',
    DueState.upcoming => days == 1 ? 'Due tomorrow' : 'Due in $days days',
  };

  static NextJabInfo compute(Jab? last, double daysBetweenJabs, DateTime now) {
    if (last == null) return const NextJabInfo(null, DueState.notStarted, 0);
    final due = addDays(last.takenAt, daysBetweenJabs);
    final days = calendarDaysBetween(now, due);
    final state = days > 0
        ? DueState.upcoming
        : days == 0
        ? DueState.dueToday
        : DueState.overdue;
    return NextJabInfo(due, state, days);
  }
}

/// Adds [days] to [t], keeping the time of day across DST changes for whole
/// days. Fractional days (e.g. 3.5) add the remainder as hours.
DateTime addDays(DateTime t, double days) {
  final whole = days.floor();
  final extraMinutes = ((days - whole) * Duration.minutesPerDay).round();
  return DateTime(
    t.year,
    t.month,
    t.day + whole,
    t.hour,
    t.minute,
    t.second,
    t.millisecond,
    t.microsecond,
  ).add(Duration(minutes: extraMinutes));
}

/// "7", "3.5": for showing an interval.
String formatDays(double d) =>
    d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
