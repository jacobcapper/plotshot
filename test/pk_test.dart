import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:plotshot/logic/pk.dart';
import 'package:plotshot/models/jab.dart';
import 'package:plotshot/models/medication.dart';

void main() {
  group('PkModel', () {
    test('peaks at the configured time to peak', () {
      for (final m in Medication.defaults) {
        final model = PkModel.fromMedication(m);
        var bestT = 0.0, best = 0.0;
        for (var t = 0.0; t < 10; t += 0.001) {
          final f = model.fraction(t);
          if (f > best) {
            best = f;
            bestT = t;
          }
        }
        expect(bestT, closeTo(m.timeToPeakDays, 0.01), reason: m.name);
      }
    });

    test('decays by half each half-life once absorbed', () {
      final model = PkModel.fromParams(6, 1.5);
      final a = model.fraction(30);
      final b = model.fraction(36);
      expect(b / a, closeTo(0.5, 0.001));
    });

    test('is zero before and at injection', () {
      final model = PkModel.fromParams(5, 1);
      expect(model.fraction(-1), 0);
      expect(model.fraction(0), 0);
    });

    test('never exceeds the dose', () {
      final model = PkModel.fromParams(7, 0.1);
      for (var t = 0.0; t < 30; t += 0.05) {
        expect(model.fraction(t), lessThanOrEqualTo(1));
      }
    });

    test('clamps an unreachable time to peak instead of failing', () {
      // tmax can't exceed 1/ke (= 7/ln2 ≈ 10.1 days for a 7 day half-life).
      final model = PkModel.fromParams(7, 12);
      expect(model.ka, greaterThan(model.ke));
      expect(model.fraction(5), greaterThan(0));
    });

    test('ka solves the tmax equation', () {
      final ke = math.ln2 / 6;
      final ka = PkModel.absorptionRateFor(ke, 1.5);
      expect(math.log(ka / ke) / (ka - ke), closeTo(1.5, 1e-6));
    });
  });

  group('LevelCalculator', () {
    const med = Medication(
      id: 1,
      name: 'Test',
      halfLifeDays: 6,
      timeToPeakDays: 1.5,
      doses: [1],
    );
    final start = DateTime(2025, 1, 1, 20);

    test('sums overlapping doses', () {
      final jabs = [
        Jab(medicationId: 1, doseMg: 2, takenAt: start),
        Jab(
          medicationId: 1,
          doseMg: 4,
          takenAt: start.add(const Duration(days: 7)),
        ),
      ];
      final calc = LevelCalculator(medications: {1: med}, jabs: jabs);
      final model = PkModel.fromMedication(med);
      final at = start.add(const Duration(days: 10));
      expect(
        calc.levelAt(1, at),
        closeTo(model.amount(2, 10) + model.amount(4, 3), 1e-9),
      );
    });

    test('ignores future jabs and other medications', () {
      final jabs = [
        Jab(medicationId: 1, doseMg: 2, takenAt: start),
        Jab(medicationId: 2, doseMg: 5, takenAt: start),
        Jab(
          medicationId: 1,
          doseMg: 9,
          takenAt: start.add(const Duration(days: 30)),
        ),
      ];
      final calc = LevelCalculator(medications: {1: med, 2: med}, jabs: jabs);
      final at = start.add(const Duration(days: 2));
      expect(
        calc.levelAt(1, at),
        closeTo(PkModel.fromMedication(med).amount(2, 2), 1e-9),
      );
    });

    test('weekly dosing approaches a steady state', () {
      final jabs = [
        for (var i = 0; i < 20; i++)
          Jab(
            medicationId: 1,
            doseMg: 6,
            takenAt: start.add(Duration(days: 7 * i)),
          ),
      ];
      final calc = LevelCalculator(medications: {1: med}, jabs: jabs);
      // Trough just before jab N, for successive weeks, converges.
      double trough(int n) => calc.levelAt(
        1,
        start.add(Duration(days: 7 * n)).subtract(const Duration(minutes: 1)),
      );
      expect((trough(19) - trough(18)).abs(), lessThan(0.05));
      // Steady-state trough for a pure exponential: D·r/(1−r), r = 0.5^(7/6).
      final r = math.pow(0.5, 7 / 6);
      expect(trough(19), closeTo(6 * r / (1 - r), 0.6));
    });

    test('series covers the range end to end', () {
      final calc = LevelCalculator(
        medications: {1: med},
        jabs: [Jab(medicationId: 1, doseMg: 2, takenAt: start)],
      );
      final end = start.add(const Duration(days: 3, hours: 1));
      final s = calc.series(1, start, end, step: const Duration(hours: 6));
      expect(s.first.time, start);
      expect(s.last.time, end);
    });
  });
}
