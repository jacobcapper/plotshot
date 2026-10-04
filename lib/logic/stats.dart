import '../models/jab.dart';
import '../models/weight_entry.dart';
import 'dates.dart';

class WeightStats {
  final double startKg;
  final double currentKg;
  final DateTime startDate;
  final DateTime endDate;

  /// Overall start weight (first entry ever), for goal progress.
  final double journeyStartKg;

  const WeightStats({
    required this.startKg,
    required this.currentKg,
    required this.startDate,
    required this.endDate,
    required this.journeyStartKg,
  });

  double get changeKg => currentKg - startKg;
  double get percentChange => startKg == 0 ? 0 : changeKg / startKg * 100;

  /// Average change per week over the range; null if under a day of data.
  double? get weeklyAvgKg {
    final days = calendarDaysBetween(startDate, endDate);
    if (days < 1) return null;
    return changeKg / days * 7;
  }

  /// Kg left to lose (or gain) to reach [goalKg].
  double toGoalKg(double goalKg) => currentKg - goalKg;

  /// Share of the journey from first weigh-in to goal completed, 0-100.
  double? goalProgress(double goalKg) {
    final total = journeyStartKg - goalKg;
    if (total == 0) return null;
    return ((journeyStartKg - currentKg) / total * 100).clamp(0, 100);
  }

  /// [entries] must be sorted by date. Returns null when there are none.
  static WeightStats? compute(List<WeightEntry> entries, {DateTime? since}) {
    if (entries.isEmpty) return null;
    final inRange = since == null
        ? entries
        : entries.where((e) => !e.date.isBefore(dateOnly(since))).toList();
    if (inRange.isEmpty) return null;
    return WeightStats(
      startKg: inRange.first.kg,
      currentKg: inRange.last.kg,
      startDate: inRange.first.date,
      endDate: inRange.last.date,
      journeyStartKg: entries.first.kg,
    );
  }
}

/// The jab most recently taken on or before [at], from [jabs] sorted oldest
/// first.
Jab? jabInEffect(List<Jab> jabs, DateTime at) {
  Jab? found;
  for (final j in jabs) {
    if (j.takenAt.isAfter(at)) break;
    found = j;
  }
  return found;
}

/// Summary of time spent on one dose, for the Results "Dosages" table.
class DoseSummary {
  final int medicationId;
  final double doseMg;
  final int jabCount;
  final DateTime first;
  final DateTime last;
  final double? startKg;
  final double? endKg;

  const DoseSummary({
    required this.medicationId,
    required this.doseMg,
    required this.jabCount,
    required this.first,
    required this.last,
    this.startKg,
    this.endKg,
  });

  double? get changeKg =>
      startKg == null || endKg == null ? null : endKg! - startKg!;
}

/// Groups consecutive jabs at the same medication and dose. A dose's weight
/// window runs from its first jab to the next dose's first jab (or today).
List<DoseSummary> doseSummaries(
  List<Jab> jabs,
  List<WeightEntry> weights,
  DateTime now,
) {
  final groups = <List<Jab>>[];
  for (final j in jabs) {
    if (groups.isNotEmpty &&
        groups.last.last.doseMg == j.doseMg &&
        groups.last.last.medicationId == j.medicationId) {
      groups.last.add(j);
    } else {
      groups.add([j]);
    }
  }
  final out = <DoseSummary>[];
  for (var i = 0; i < groups.length; i++) {
    final g = groups[i];
    final from = dateOnly(g.first.takenAt);
    final to = i + 1 < groups.length
        ? dateOnly(groups[i + 1].first.takenAt)
        : dateOnly(now);
    final window = weights.where(
      (w) => !w.date.isBefore(from) && !w.date.isAfter(to),
    );
    // Use the last weight before the dose started as its baseline if there is
    // one, so back-to-back doses chain together.
    final before = weights.where((w) => w.date.isBefore(from));
    final startKg = before.isNotEmpty
        ? before.last.kg
        : (window.isNotEmpty ? window.first.kg : null);
    out.add(
      DoseSummary(
        medicationId: g.first.medicationId,
        doseMg: g.first.doseMg,
        jabCount: g.length,
        first: g.first.takenAt,
        last: g.last.takenAt,
        startKg: startKg,
        endKg: window.isNotEmpty ? window.last.kg : null,
      ),
    );
  }
  return out;
}
