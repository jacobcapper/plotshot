import 'package:plotshot/data/app_state.dart';
import 'package:plotshot/data/database.dart';
import 'package:plotshot/data/settings.dart';
import 'package:plotshot/models/jab.dart';
import 'package:plotshot/models/medication.dart';
import 'package:plotshot/models/weight_entry.dart';
import 'package:plotshot/services/health_service.dart';
import 'package:plotshot/services/notification_service.dart';
import 'package:plotshot/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeHealth implements HealthService {
  HealthData data = HealthData([], []);
  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.available;
  @override
  Future<void> installHealthConnect() async {}
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<HealthData> read(DateTime start, DateTime end) async => data;
}

class RecordingNotifications extends NoopNotificationService {
  List<Reminder> scheduled = [];
  @override
  Future<void> scheduleReminders(List<Reminder> reminders) async {
    scheduled = reminders;
  }
}

Future<AppState> makeState({
  bool seed = false,
  WidgetService widgets = const NoopWidgetService(),
}) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  SharedPreferences.setMockInitialValues({});
  final db = await AppDatabase.open(
    path: inMemoryDatabasePath,
    singleInstance: false,
  );
  final state = AppState(
    db,
    await Settings.load(),
    notifications: RecordingNotifications(),
    health: FakeHealth(),
    widgets: widgets,
  );
  await state.load();
  if (seed) await seedSample(state);
  return state;
}

/// Eight weekly Retatrutide jabs stepping 2 → 6 mg, with weights, similar to
/// a real log.
Future<void> seedSample(AppState state) async {
  final med = state.medications.firstWhere((m) => m.name == 'Retatrutide');
  final now = DateTime.now();
  final first = DateTime(now.year, now.month, now.day - 7 * 7 - 2, 23, 30);
  const doses = <double>[2, 3, 4, 5, 5, 6, 6, 6];
  const sites = [
    'Stomach - Upper Left',
    'Stomach - Upper Mid',
    'Stomach - Upper Right',
    'Stomach - Lower Left',
    'Stomach - Lower Mid',
    'Stomach - Lower Right',
    'Stomach - Upper Left',
    'Stomach - Lower Left',
  ];
  for (var i = 0; i < doses.length; i++) {
    await state.saveJab(
      Jab(
        medicationId: med.id!,
        doseMg: doses[i],
        takenAt: first.add(Duration(days: 7 * i)),
        site: sites[i],
      ),
    );
  }
  const kgs = <double>[
    143.5,
    142,
    140.8,
    139.6,
    138.2,
    137.4,
    136.6,
    136.1,
    136.1,
  ];
  for (var i = 0; i < kgs.length; i++) {
    await state.saveWeight(
      WeightEntry(
        date: first.add(Duration(days: 6 * i)),
        kg: kgs[i],
      ),
    );
  }
  await state.updateSettings((s) {
    s.heightCm = 190.5;
    s.goalKg = 120;
  });
}

/// Adds a twice-weekly custom medication alongside the sample Retatrutide.
Future<Medication> seedSecondMedication(AppState state) async {
  final med = await state.saveMedication(
    const Medication(
      name: 'Testosterone Enanthate',
      halfLifeDays: 4.5,
      timeToPeakDays: 1.5,
      doses: [50, 62.5, 75, 100],
      daysBetweenJabs: 3.5,
      sites: ['Glute - Left', 'Glute - Right', 'Thigh - Left', 'Thigh - Right'],
    ),
  );
  final now = DateTime.now();
  for (var i = 6; i >= 0; i--) {
    await state.saveJab(
      Jab(
        medicationId: med.id!,
        doseMg: 75,
        takenAt: now.subtract(Duration(hours: (i * 3.5 * 24 + 30).round())),
        site: med.sites[i % med.sites.length],
      ),
    );
  }
  return state.medication(med.id)!;
}
