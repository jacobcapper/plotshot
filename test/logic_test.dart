import 'package:flutter_test/flutter_test.dart';
import 'package:plotshot/logic/schedule.dart';
import 'package:plotshot/logic/sites.dart';
import 'package:plotshot/logic/stats.dart';
import 'package:plotshot/logic/units.dart';
import 'package:plotshot/models/jab.dart';
import 'package:plotshot/models/weight_entry.dart';

void main() {
  group('sites', () {
    test('rotates in order and wraps', () {
      expect(nextSite(['A', 'B', 'C'], 'A'), 'B');
      expect(nextSite(['A', 'B', 'C'], 'C'), 'A');
    });
    test('starts at the beginning for unknown or missing sites', () {
      expect(nextSite(['A', 'B'], null), 'A');
      expect(nextSite(['A', 'B'], 'Z'), 'A');
      expect(nextSite([], 'A'), isNull);
    });
  });

  group('schedule', () {
    final last = Jab(
      medicationId: 1,
      doseMg: 6,
      takenAt: DateTime(2025, 8, 19, 23, 30),
    );
    test('upcoming, due today and overdue', () {
      expect(
        NextJabInfo.compute(last, 7, DateTime(2025, 8, 22)).label,
        'Due in 4 days',
      );
      expect(
        NextJabInfo.compute(last, 7, DateTime(2025, 8, 25, 9)).label,
        'Due tomorrow',
      );
      expect(
        NextJabInfo.compute(last, 7, DateTime(2025, 8, 26, 8)).state,
        DueState.dueToday,
      );
      expect(
        NextJabInfo.compute(last, 7, DateTime(2025, 8, 27)).label,
        'Due yesterday',
      );
      expect(
        NextJabInfo.compute(last, 7, DateTime(2025, 9, 1)).label,
        'Overdue by 6 days',
      );
    });
    test('no jabs yet', () {
      expect(
        NextJabInfo.compute(null, 7, DateTime.now()).state,
        DueState.notStarted,
      );
    });
  });

  group('weight stats', () {
    final weights = [
      WeightEntry(date: DateTime(2025, 7, 8), kg: 143.5),
      WeightEntry(date: DateTime(2025, 7, 22), kg: 140),
      WeightEntry(date: DateTime(2025, 8, 19), kg: 136.1),
    ];
    test('all time', () {
      final s = WeightStats.compute(weights)!;
      expect(s.changeKg, closeTo(-7.4, 1e-9));
      expect(s.percentChange, closeTo(-5.157, 0.01));
      expect(s.weeklyAvgKg, closeTo(-7.4 / 42 * 7, 1e-9));
      expect(s.toGoalKg(120), closeTo(16.1, 1e-9));
      expect(s.goalProgress(120), closeTo(7.4 / 23.5 * 100, 1e-6));
    });
    test('range keeps journey start', () {
      final s = WeightStats.compute(weights, since: DateTime(2025, 7, 20))!;
      expect(s.startKg, 140);
      expect(s.journeyStartKg, 143.5);
    });
    test('empty', () {
      expect(WeightStats.compute([]), isNull);
    });
  });

  group('dose summaries', () {
    test('groups consecutive doses with weight change', () {
      final jabs = [
        Jab(medicationId: 1, doseMg: 2, takenAt: DateTime(2025, 7, 1)),
        Jab(medicationId: 1, doseMg: 2, takenAt: DateTime(2025, 7, 8)),
        Jab(medicationId: 1, doseMg: 4, takenAt: DateTime(2025, 7, 15)),
      ];
      final weights = [
        WeightEntry(date: DateTime(2025, 6, 30), kg: 100),
        WeightEntry(date: DateTime(2025, 7, 14), kg: 98),
        WeightEntry(date: DateTime(2025, 7, 20), kg: 97),
      ];
      final s = doseSummaries(jabs, weights, DateTime(2025, 7, 21));
      expect(s, hasLength(2));
      expect(s[0].jabCount, 2);
      expect(s[0].changeKg, closeTo(-2, 1e-9));
      expect(s[1].doseMg, 4);
      expect(s[1].changeKg, closeTo(-1, 1e-9));
    });
  });

  group('units', () {
    test('formats weights', () {
      expect(formatWeight(136.1, WeightUnit.kg), '136.1 kg');
      expect(formatWeight(100, WeightUnit.lb), '220.5 lb');
      expect(
        formatWeight(kgPerLb * (21 * 14 + 6), WeightUnit.st),
        '21st 6.0lb',
      );
      // Rounding up to 14lb rolls over to the next stone.
      expect(
        formatWeight(kgPerLb * (13.98 + 14 * 10), WeightUnit.st),
        '11st 0.0lb',
      );
    });
    test('formats height and BMI', () {
      expect(formatHeight(190.5, HeightUnit.ftIn), '6\' 3"');
      expect(bmi(136.1, 190.5), closeTo(37.5, 0.05));
    });
    test('formats doses', () {
      expect(formatDose(6), '6');
      expect(formatDose(2.5), '2.5');
      expect(formatDose(0.25), '0.25');
    });
  });
}
