import 'package:flutter_test/flutter_test.dart';
import 'package:plotshot/data/app_state.dart';
import 'package:plotshot/data/database.dart';
import 'package:plotshot/data/settings.dart';
import 'package:plotshot/logic/dates.dart';
import 'package:plotshot/logic/schedule.dart';
import 'package:plotshot/models/day_log.dart';
import 'package:plotshot/models/jab.dart';
import 'package:plotshot/models/medication.dart';
import 'package:plotshot/models/weight_entry.dart';
import 'package:plotshot/services/health_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fixtures.dart';

Medication reta(AppState s) =>
    s.medications.firstWhere((m) => m.name == 'Retatrutide');

void main() {
  test('seeds built-in medications, off schedule until used', () async {
    final s = await makeState();
    expect(s.medications.map((m) => m.name), [
      'Retatrutide',
      'Tirzepatide',
      'Semaglutide',
    ]);
    expect(s.medications.every((m) => !m.active), isTrue);
    expect(s.scheduledMedications, isEmpty);
    expect(s.defaultMedication?.name, 'Retatrutide');
  });

  test('sample data gives a non-zero level and a schedule', () async {
    final s = await makeState(seed: true);
    final m = reta(s);
    expect(s.jabs, hasLength(8));
    expect(m.active, isTrue);
    expect(s.levelOf(m), greaterThan(5));
    expect(s.nextDose(m), 6);
    expect(s.nextSiteFor(m), 'Stomach - Lower Mid');
    expect(s.scheduledMedications.map((m) => m.name), ['Retatrutide']);
  });

  group('two medications on their own schedules', () {
    late AppState s;
    late Medication r, t;
    final now = DateTime.now();

    setUp(() async {
      s = await makeState(seed: true);
      r = reta(s);
      t = await s.saveMedication(
        const Medication(
          name: 'Test E',
          halfLifeDays: 4.5,
          timeToPeakDays: 1.5,
          doses: [62.5, 75, 100],
          daysBetweenJabs: 3.5,
          sites: ['Glute - Left', 'Glute - Right'],
        ),
      );
      // Last Test E jab two days ago; Reta's was ~2 days ago too (fixture).
      await s.saveJab(
        Jab(
          medicationId: t.id!,
          doseMg: 75,
          takenAt: now.subtract(const Duration(days: 5, hours: 12)),
          site: 'Glute - Left',
        ),
      );
      await s.saveJab(
        Jab(
          medicationId: t.id!,
          doseMg: 75,
          takenAt: now.subtract(const Duration(days: 2)),
          site: 'Glute - Right',
        ),
      );
      t = s.medication(t.id)!;
    });

    test('due dates follow each interval', () {
      final lastR = s.lastJabFor(r.id!)!.takenAt;
      final lastT = s.lastJabFor(t.id!)!.takenAt;
      expect(s.nextJab(r).due, addDays(lastR, 7));
      expect(s.nextJab(t).due, lastT.add(const Duration(days: 3, hours: 12)));
    });

    test('soonest due medication is listed and defaulted first', () {
      expect(s.scheduledMedications.map((m) => m.name), [
        'Test E',
        'Retatrutide',
      ]);
      expect(s.defaultMedication?.name, 'Test E');
    });

    test('dose, site and jab numbers are per medication', () {
      expect(s.nextDose(t), 75);
      expect(s.nextDose(r), 6);
      expect(s.nextSiteFor(t), 'Glute - Left');
      expect(s.nextSiteFor(r), 'Stomach - Lower Mid');
      expect(s.jabNumber(s.lastJabFor(t.id!)!), 2);
      expect(s.jabNumber(s.lastJabFor(r.id!)!), 8);
    });

    test('levels are tracked separately', () {
      expect(s.levelOf(t), greaterThan(50));
      expect(s.levelOf(r), lessThan(15));
    });

    test('planned dose change applies to one medication only', () async {
      await s.setNextDose(t, 100);
      expect(s.nextDose(s.medication(t.id)!), 100);
      expect(s.nextDose(s.medication(r.id)!), 6);
      await s.saveJab(
        Jab(medicationId: t.id!, doseMg: 100, takenAt: DateTime.now()),
      );
      expect(s.medication(t.id)!.nextDoseMg, isNull);
    });

    test('each medication gets its own reminders', () async {
      final n = s.notifications as RecordingNotifications;
      await s.updateSettings((x) => x.remindersEnabled = true);
      final titles = n.scheduled.map((r) => r.title).toSet();
      expect(titles, {'Retatrutide jab day', 'Test E jab day'});
      final ids = n.scheduled.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(
        n.scheduled.where((x) => x.title.startsWith('Test E')).first.at.day,
        s.nextJab(s.medication(t.id)!).due!.day,
      );

      // Stopping a medication drops its reminders.
      await s.saveMedication(s.medication(t.id)!.copyWith(active: false));
      expect(n.scheduled.map((r) => r.title).toSet(), {'Retatrutide jab day'});
      await s.updateSettings((x) => x.remindersEnabled = false);
      expect(n.scheduled, isEmpty);
    });
  });

  test('logging a jab puts an inactive medication on a schedule', () async {
    final s = await makeState();
    final tirz = s.medications.firstWhere((m) => m.name == 'Tirzepatide');
    await s.saveJab(
      Jab(medicationId: tirz.id!, doseMg: 2.5, takenAt: DateTime.now()),
    );
    expect(s.medication(tirz.id)!.active, isTrue);
    expect(s.scheduledMedications.single.name, 'Tirzepatide');
  });

  test('reminder times: due day plus follow-ups, only in the future', () async {
    final s = await makeState(seed: true);
    final due = s.nextJab(reta(s)).due!;
    final times = s.reminderTimes(
      due,
      DateTime(due.year, due.month, due.day - 1),
    );
    expect(times, hasLength(4));
    expect(times.first.hour, 9);
    expect(sameDay(times.first, due), isTrue);
  });

  test('cannot delete a medication with jabs', () async {
    final s = await makeState(seed: true);
    expect(() => s.deleteMedication(reta(s)), throwsStateError);
    final unused = s.medications.firstWhere((m) => m.name == 'Semaglutide');
    await s.deleteMedication(unused);
    expect(s.medications, hasLength(2));
  });

  test('migrates the old shared schedule onto medications', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({
      'daysBetweenJabs': 10,
      'rotation': ['Thigh - Left', 'Thigh - Right'],
      'nextDoseMg': 8.0,
      'nextMedicationId': 1,
    });
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      singleInstance: false,
    );
    await db.saveJab(
      Jab(medicationId: 1, doseMg: 6, takenAt: DateTime(2025, 8, 19)),
    );
    final settings = await Settings.load();
    expect(settings.legacy, isNotNull);
    final s = AppState(
      db,
      settings,
      notifications: RecordingNotifications(),
      health: FakeHealth(),
    );
    await s.load();
    final r = s.medication(1)!;
    expect(r.daysBetweenJabs, 10);
    expect(r.sites, ['Thigh - Left', 'Thigh - Right']);
    expect(r.nextDoseMg, 8);
    expect(r.active, isTrue);
    expect(s.medication(2)!.active, isFalse);
    expect(s.medication(2)!.nextDoseMg, isNull);
    expect(s.settings.legacy, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('daysBetweenJabs'), isFalse);
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

  test('backup round trip keeps per-medication schedules', () async {
    final a = await makeState(seed: true);
    await a.saveMedication(
      reta(a).copyWith(daysBetweenJabs: 5, sites: ['Arm - Left']),
    );
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
    expect(reta(b).daysBetweenJabs, 5);
    expect(reta(b).sites, ['Arm - Left']);
    expect(b.levelOf(reta(b)), closeTo(a.levelOf(reta(a)), 0.01));
  });

  test('a v1 backup gets its shared schedule applied', () async {
    final a = await makeState(seed: true);
    final json = a.exportData();
    json['version'] = 1;
    (json['settings'] as Map<String, Object?>)
      ..['daysBetweenJabs'] = 14
      ..['rotation'] = ['Thigh - Left'];
    for (final m in json['medications'] as List) {
      (m as Map).removeWhere(
        (k, _) => [
          'days_between_jabs',
          'active',
          'sites',
          'next_dose_mg',
        ].contains(k),
      );
    }
    final b = await makeState();
    await b.importData(json);
    expect(reta(b).daysBetweenJabs, 14);
    expect(reta(b).sites, ['Thigh - Left']);
    expect(reta(b).active, isTrue);
    expect(
      b.medications.firstWhere((m) => m.name == 'Semaglutide').active,
      isFalse,
    );
  });

  test('import rejects other files', () async {
    final s = await makeState();
    expect(() => s.importData({'hello': 'world'}), throwsFormatException);
  });
}
