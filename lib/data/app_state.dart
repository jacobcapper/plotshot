import 'package:flutter/foundation.dart';

import '../logic/dates.dart';
import '../logic/pk.dart';
import '../logic/schedule.dart';
import '../logic/sites.dart';
import '../logic/units.dart';
import '../models/day_log.dart';
import '../models/jab.dart';
import '../models/medication.dart';
import '../models/weight_entry.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import 'backup.dart';
import 'database.dart';
import 'settings.dart';

/// The app's in-memory model. Data sets are small (a jab a week, a weight a
/// day), so everything is loaded up front and kept in sorted lists.
class AppState extends ChangeNotifier {
  final AppDatabase _db;
  final Settings settings;
  final NotificationService notifications;
  final HealthService health;

  List<Medication> medications = [];
  List<Jab> jabs = []; // oldest first
  List<WeightEntry> weights = []; // oldest first
  Map<String, DayLog> dayLogs = {}; // by day key

  LevelCalculator? _levels;

  AppState(
    this._db,
    this.settings, {
    required this.notifications,
    required this.health,
  });

  Future<void> load() async {
    medications = await _db.medications();
    jabs = await _db.jabs();
    weights = await _db.weights();
    dayLogs = {for (final l in await _db.dayLogs()) dayKey(l.date): l};
    await _migrateLegacySchedule();
    _changed(reschedule: true);
  }

  /// Copies the pre-v2 global interval, site rotation and planned dose onto
  /// each medication, once.
  Future<void> _migrateLegacySchedule() async {
    final legacy = settings.legacy;
    if (legacy == null) return;
    for (final m in [...medications]) {
      final updated = m.copyWith(
        daysBetweenJabs: legacy.daysBetweenJabs?.toDouble(),
        active: medicationInUse(m),
        sites: legacy.rotation,
        nextDoseMg: legacy.nextMedicationId == m.id
            ? legacy.nextDoseMg
            : m.nextDoseMg,
      );
      await _db.saveMedication(updated);
    }
    medications = await _db.medications();
    settings.legacy = null;
    await settings.save();
  }

  void _changed({bool reschedule = false}) {
    _levels = null;
    notifyListeners();
    if (reschedule) {
      rescheduleReminders();
    }
  }

  // ---- Derived data ----

  Map<int, Medication> get medicationsById => {
    for (final m in medications) m.id!: m,
  };

  Medication? medication(int? id) =>
      medications.where((m) => m.id == id).firstOrNull;

  LevelCalculator get levels =>
      _levels ??= LevelCalculator(medications: medicationsById, jabs: jabs);

  Jab? get lastJab => jabs.isEmpty ? null : jabs.last;

  List<Jab> jabsFor(int medicationId) =>
      jabs.where((j) => j.medicationId == medicationId).toList();

  Jab? lastJabFor(int medicationId) {
    for (var i = jabs.length - 1; i >= 0; i--) {
      if (jabs[i].medicationId == medicationId) return jabs[i];
    }
    return null;
  }

  /// 1-based position of [jab] among jabs of the same medication.
  int jabNumber(Jab jab) =>
      jabs
          .where((j) => j.medicationId == jab.medicationId)
          .toList()
          .indexWhere((j) => j.id == jab.id) +
      1;

  WeightEntry? get latestWeight => weights.isEmpty ? null : weights.last;

  WeightEntry? weightOn(DateTime day) =>
      weights.where((w) => sameDay(w.date, day)).firstOrNull;

  DayLog dayLog(DateTime day) => dayLogs[dayKey(day)] ?? DayLog(date: day);

  List<Jab> jabsOn(DateTime day) =>
      jabs.where((j) => sameDay(j.takenAt, day)).toList();

  /// Medications with at least one jab, most recently used first.
  List<Medication> get medicationsInUse => levels
      .medicationsInUse()
      .map(medication)
      .whereType<Medication>()
      .toList();

  /// Active medications that have a schedule to show, soonest due first.
  /// Medications with no jabs yet come last.
  List<Medication> get scheduledMedications {
    final now = DateTime.now();
    final meds = medications.where((m) => m.active).toList();
    meds.sort((a, b) {
      final da = nextJab(a, now).due, db = nextJab(b, now).due;
      if (da == null || db == null) {
        return da == null ? (db == null ? a.id!.compareTo(b.id!) : 1) : -1;
      }
      return da.compareTo(db);
    });
    return meds;
  }

  /// The medication the weight chart is coloured by: the user's choice, or
  /// the built-in medication with the most jabs, or the most used.
  Medication? get chartMedication {
    final chosen = medication(settings.chartMedicationId);
    if (chosen != null && jabs.any((j) => j.medicationId == chosen.id)) {
      return chosen;
    }
    final inUse = medicationsInUse;
    if (inUse.isEmpty) return null;
    int count(Medication m) => jabs.where((j) => j.medicationId == m.id).length;
    final sorted = [...inUse]
      ..sort((a, b) {
        if (a.builtIn != b.builtIn) return a.builtIn ? -1 : 1;
        return count(b).compareTo(count(a));
      });
    return sorted.first;
  }

  double levelOf(Medication m, [DateTime? at]) =>
      levels.levelAt(m.id!, at ?? DateTime.now());

  NextJabInfo nextJab(Medication m, [DateTime? now]) => NextJabInfo.compute(
    lastJabFor(m.id!),
    m.daysBetweenJabs,
    now ?? DateTime.now(),
  );

  /// The medication a new jab defaults to: the active one due soonest.
  Medication? get defaultMedication =>
      scheduledMedications.firstOrNull ??
      medication(lastJab?.medicationId) ??
      medications.firstOrNull;

  double? nextDose(Medication m) =>
      m.nextDoseMg ?? lastJabFor(m.id!)?.doseMg ?? m.doses.firstOrNull;

  String? nextSiteFor(Medication m) =>
      nextSite(m.sites, lastJabFor(m.id!)?.site);

  // ---- Jabs ----

  Future<void> saveJab(Jab jab) async {
    final saved = await _db.saveJab(jab);
    jabs = [...jabs.where((j) => j.id != saved.id), saved]
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    // A newly logged latest jab consumes any planned dose change, and puts
    // the medication on a schedule if it wasn't.
    final med = medication(saved.medicationId);
    if (jab.id == null &&
        med != null &&
        identical(lastJabFor(med.id!), saved) &&
        (med.nextDoseMg != null || !med.active)) {
      final updated = med.copyWith(nextDoseMg: null, active: true);
      await _db.saveMedication(updated);
      _replaceMedication(updated);
    }
    _changed(reschedule: true);
  }

  Future<void> deleteJab(Jab jab) async {
    await _db.deleteJab(jab.id!);
    jabs = jabs.where((j) => j.id != jab.id).toList();
    _changed(reschedule: true);
  }

  Future<void> setNextDose(Medication m, double doseMg) =>
      saveMedication(m.copyWith(nextDoseMg: doseMg));

  // ---- Weights & day logs ----

  Future<void> saveWeight(WeightEntry w) async {
    await _db.saveWeight(w);
    weights = [...weights.where((e) => !sameDay(e.date, w.date)), w]
      ..sort((a, b) => a.date.compareTo(b.date));
    _changed();
  }

  Future<void> deleteWeight(DateTime day) async {
    await _db.deleteWeight(day);
    weights = weights.where((e) => !sameDay(e.date, day)).toList();
    _changed();
  }

  Future<void> saveDayLog(DayLog log) async {
    await _db.saveDayLog(log);
    final k = dayKey(log.date);
    dayLogs = {...dayLogs}..remove(k);
    if (!log.isEmpty) dayLogs[k] = log;
    _changed();
  }

  // ---- Medications ----

  void _replaceMedication(Medication m) {
    medications = [...medications.where((e) => e.id != m.id), m]
      ..sort((a, b) => a.id!.compareTo(b.id!));
  }

  Future<Medication> saveMedication(Medication m) async {
    final saved = await _db.saveMedication(m);
    _replaceMedication(saved);
    _changed(reschedule: true);
    return saved;
  }

  bool medicationInUse(Medication m) => jabs.any((j) => j.medicationId == m.id);

  Future<void> deleteMedication(Medication m) async {
    if (medicationInUse(m)) {
      throw StateError('${m.name} has jabs logged against it');
    }
    await _db.deleteMedication(m.id!);
    medications = medications.where((e) => e.id != m.id).toList();
    _changed(reschedule: true);
  }

  // ---- Settings ----

  Future<void> updateSettings(void Function(Settings s) change) async {
    change(settings);
    await settings.save();
    _changed(reschedule: true);
  }

  /// How many daily follow-ups to send if a jab day is missed.
  static const missedJabFollowUps = 3;

  /// One set of reminders per active medication that has been started.
  Future<void> rescheduleReminders() async {
    try {
      final now = DateTime.now();
      final reminders = <Reminder>[];
      if (settings.remindersEnabled) {
        for (final m in medications.where((m) => m.active)) {
          final due = nextJab(m, now).due;
          if (due == null) continue;
          final dose = nextDose(m);
          final times = reminderTimes(due, now);
          for (var i = 0; i < times.length; i++) {
            reminders.add(
              Reminder(
                id: m.id! * 10 + i,
                at: times[i],
                title: '${m.name} jab day',
                body:
                    'Time for your ${m.name}'
                    '${dose == null ? '' : ' ${formatDose(dose)} mg'} jab.',
              ),
            );
          }
        }
      }
      await notifications.scheduleReminders(reminders);
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    }
  }

  /// The due-day reminder plus daily follow-ups, skipping any already past.
  List<DateTime> reminderTimes(DateTime due, DateTime now) {
    final t = settings.reminderTime;
    return [
      for (var i = 0; i <= missedJabFollowUps; i++)
        DateTime(due.year, due.month, due.day + i, t.hour, t.minute),
    ].where((d) => d.isAfter(now)).toList();
  }

  // ---- Health Connect ----

  /// Pulls weight, calories and protein for the last [days] days. Manual
  /// entries always win over synced ones. Returns the number of days updated.
  Future<int> syncHealth({int days = 90}) async {
    final end = DateTime.now();
    final start = settings.lastHealthSync == null
        ? end.subtract(Duration(days: days))
        : settings.lastHealthSync!.subtract(const Duration(days: 2));
    final data = await health.read(start, end);
    var updated = 0;
    for (final w in data.weights) {
      final existing = weightOn(w.date);
      if (existing != null &&
          (existing.source == 'manual' || existing.kg == w.kg)) {
        continue;
      }
      await _db.saveWeight(w);
      updated++;
    }
    for (final n in data.nutrition) {
      final log = dayLog(n.date);
      final hasManual =
          !log.nutritionFromHealth &&
          (log.calories != null || log.proteinG != null);
      if (hasManual) continue;
      await _db.saveDayLog(
        log.copyWith(
          calories: n.calories,
          proteinG: n.proteinG,
          nutritionFromHealth: true,
        ),
      );
      updated++;
    }
    settings.lastHealthSync = end;
    await settings.save();
    await load();
    return updated;
  }

  // ---- Backup ----

  Map<String, Object?> exportData() => Backup.encode(
    settings: settings,
    medications: medications,
    jabs: jabs,
    weights: weights,
    dayLogs: dayLogs.values.toList(),
  );

  Future<void> importData(Map<String, Object?> json) async {
    final b = Backup.decode(json);
    await _db.replaceAll(
      medications: b.medications,
      jabs: b.jabs,
      weights: b.weights,
      dayLogs: b.dayLogs,
    );
    settings.applyJson(b.settings);
    // A v1 backup carries the old shared schedule.
    settings.legacy = b.version < 2
        ? LegacySchedule.fromJson(b.settings)
        : null;
    await settings.save();
    await load();
  }
}
