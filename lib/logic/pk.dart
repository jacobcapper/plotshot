import 'dart:math' as math;

import '../models/jab.dart';
import '../models/medication.dart';
import 'dates.dart';

/// One-compartment model with first-order absorption and elimination (the
/// Bateman function). Gives the estimated amount of drug in the body, in mg,
/// [t] days after a dose of [dose] mg.
///
/// The absorption rate is derived from the medication's time to peak, so the
/// user only has to supply two familiar numbers: half-life and time to peak.
class PkModel {
  /// Elimination rate constant, per day.
  final double ke;

  /// Absorption rate constant, per day.
  final double ka;

  PkModel._(this.ke, this.ka);

  factory PkModel.fromMedication(Medication m) =>
      PkModel.fromParams(m.halfLifeDays, m.timeToPeakDays);

  factory PkModel.fromParams(double halfLifeDays, double timeToPeakDays) {
    final ke = math.ln2 / halfLifeDays;
    return PkModel._(ke, absorptionRateFor(ke, timeToPeakDays));
  }

  /// Solves tmax = ln(ka/ke) / (ka - ke) for ka > ke.
  ///
  /// tmax is strictly decreasing in ka, approaching 1/ke as ka -> ke. A time to
  /// peak at or beyond 1/ke can't be reached with ka > ke, so it is clamped to
  /// just above ke (the slowest-absorbing curve).
  static double absorptionRateFor(double ke, double tmaxDays) {
    if (tmaxDays <= 0) return ke * 1e4;
    double tmaxOf(double ka) => math.log(ka / ke) / (ka - ke);
    var lo = ke * (1 + 1e-6);
    if (tmaxOf(lo) <= tmaxDays) return lo;
    var hi = ke * 2;
    while (tmaxOf(hi) > tmaxDays) {
      hi *= 2;
    }
    for (var i = 0; i < 100; i++) {
      final mid = (lo + hi) / 2;
      if (tmaxOf(mid) > tmaxDays) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Amount remaining in the body, as a fraction of the dose, [t] days after
  /// injection.
  double fraction(double t) {
    if (t <= 0) return 0;
    if ((ka - ke).abs() < 1e-9) return ke * t * math.exp(-ke * t);
    return ka / (ka - ke) * (math.exp(-ke * t) - math.exp(-ka * t));
  }

  double amount(double dose, double t) => dose * fraction(t);
}

class LevelPoint {
  final DateTime time;
  final double mg;
  const LevelPoint(this.time, this.mg);
}

/// Estimated levels across all jabs, grouped by medication.
class LevelCalculator {
  final Map<int, Medication> medications;
  final List<Jab> jabs;
  final Map<int, PkModel> _models = {};

  LevelCalculator({required this.medications, required this.jabs});

  PkModel? _model(int medicationId) {
    final med = medications[medicationId];
    if (med == null) return null;
    return _models.putIfAbsent(medicationId, () => PkModel.fromMedication(med));
  }

  /// Estimated mg of [medicationId] in the body at [at].
  double levelAt(int medicationId, DateTime at) {
    final model = _model(medicationId);
    if (model == null) return 0;
    var total = 0.0;
    for (final j in jabs) {
      if (j.medicationId != medicationId || j.takenAt.isAfter(at)) continue;
      total += model.amount(j.doseMg, daysBetween(j.takenAt, at));
    }
    return total;
  }

  /// Samples the level of [medicationId] from [start] to [end].
  List<LevelPoint> series(
    int medicationId,
    DateTime start,
    DateTime end, {
    Duration step = const Duration(hours: 3),
  }) {
    final points = <LevelPoint>[];
    var t = start;
    while (!t.isAfter(end)) {
      points.add(LevelPoint(t, levelAt(medicationId, t)));
      t = t.add(step);
    }
    if (points.isEmpty || points.last.time.isBefore(end)) {
      points.add(LevelPoint(end, levelAt(medicationId, end)));
    }
    return points;
  }

  /// The medications with any jabs, most recently used first.
  List<int> medicationsInUse() {
    final sorted = [...jabs]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final ids = <int>[];
    for (final j in sorted) {
      if (!ids.contains(j.medicationId)) ids.add(j.medicationId);
    }
    return ids;
  }
}
