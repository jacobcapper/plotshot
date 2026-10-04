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

  static NextJabInfo compute(Jab? last, int daysBetweenJabs, DateTime now) {
    if (last == null) return const NextJabInfo(null, DueState.notStarted, 0);
    final t = last.takenAt;
    final due = DateTime(
      t.year,
      t.month,
      t.day + daysBetweenJabs,
      t.hour,
      t.minute,
    );
    final days = calendarDaysBetween(now, due);
    final state = days > 0
        ? DueState.upcoming
        : days == 0
        ? DueState.dueToday
        : DueState.overdue;
    return NextJabInfo(due, state, days);
  }
}
