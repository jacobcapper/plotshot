import 'package:flutter_test/flutter_test.dart';
import 'package:plotshot/logic/dates.dart';
import 'package:plotshot/models/day_log.dart';
import 'package:plotshot/models/jab.dart';
import 'package:plotshot/models/weight_entry.dart';
import 'package:plotshot/services/health_service.dart';

import 'support/fixtures.dart';

void main() {
  test('seeds built-in medications', () async {
    final s = await makeState();
    expect(s.medications.map((m) => m.name), [
      'Retatrutide',
      'Tirzepatide',
      'Semaglutide',
    ]);
  });

  test('sample data gives a non-zero current level', () async {
    final s = await makeState(seed: true);
    expect(s.jabs, hasLength(8));
    expect(s.currentLevel(), greaterThan(5));
    expect(s.nextDose, 6);
    expect(s.nextSiteSuggestion, 'Stomach - Lower Mid');
  });

  test('logging the next jab clears a planned dose change', () async {
    final s = await makeState(seed: true);
    final med = s.nextMedication!;
    await s.setNextDose(med.id!, 7);
    expect(s.nextDose, 7);
    await s.saveJab(
      Jab(medicationId: med.id!, doseMg: 7, takenAt: DateTime.now()),
    );
    expect(s.settings.nextDoseMg, isNull);
    expect(s.nextDose, 7); // now from the last jab
  });

  test('reminders: due day plus follow-ups, only in the future', () async {
    final s = await makeState(seed: true);
    final n = s.notifications as RecordingNotifications;
    await s.updateSettings((x) => x.remindersEnabled = true);
    final due = s.nextJab().due!;
    final times = s.reminderTimes(
      due,
      DateTime(due.year, due.month, due.day - 1),
    );
    expect(times, hasLength(4));
    expect(times.first.hour, 9);
    expect(sameDay(times.first, due), isTrue);
    expect(n.scheduled, isNotEmpty);
    await s.updateSettings((x) => x.remindersEnabled = false);
    expect(n.scheduled, isEmpty);
  });

  test('cannot delete a medication with jabs', () async {
    final s = await makeState(seed: true);
    final med = s.nextMedication!;
    expect(() => s.deleteMedication(med), throwsStateError);
    final unused = s.medications.firstWhere((m) => m.name == 'Semaglutide');
    await s.deleteMedication(unused);
    expect(s.medications, hasLength(2));
  });

  test('health sync never overwrites manual entries', () async {
    final s = await makeState();
    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    await s.saveWeight(WeightEntry(date: today, kg: 100));
    await s.saveDayLog(DayLog(date: today, calories: 1500));
    (s.health as FakeHealth).data = HealthData(
      [
        WeightEntry(date: today, kg: 99, source: 'health_connect'),
        WeightEntry(date: yesterday, kg: 101, source: 'health_connect'),
      ],
      [DailyNutrition(today, 2000, 100), DailyNutrition(yesterday, 1800, 90)],
    );
    await s.syncHealth();
    expect(s.weightOn(today)!.kg, 100);
    expect(s.weightOn(yesterday)!.kg, 101);
    expect(s.dayLog(today).calories, 1500);
    expect(s.dayLog(yesterday).calories, 1800);
    expect(s.dayLog(yesterday).nutritionFromHealth, isTrue);

    // Synced values do update on later syncs.
    (s.health as FakeHealth).data = HealthData(
      [WeightEntry(date: yesterday, kg: 100.5, source: 'health_connect')],
      [DailyNutrition(yesterday, 1900, 95)],
    );
    await s.syncHealth();
    expect(s.weightOn(yesterday)!.kg, 100.5);
    expect(s.dayLog(yesterday).calories, 1900);
  });

  test('backup round trip', () async {
    final a = await makeState(seed: true);
    await a.saveDayLog(
      DayLog(date: DateTime.now(), sideEffects: ['Nausea'], notes: 'Tired'),
    );
    final json = a.exportData();

    final b = await makeState();
    await b.importData(json);
    expect(b.jabs, hasLength(8));
    expect(b.weights, hasLength(a.weights.length));
    expect(b.dayLog(DateTime.now()).sideEffects, ['Nausea']);
    expect(b.settings.goalKg, 120);
    expect(b.currentLevel(), closeTo(a.currentLevel(DateTime.now()), 0.01));
  });

  test('import rejects other files', () async {
    final s = await makeState();
    expect(() => s.importData({'hello': 'world'}), throwsFormatException);
  });
}
