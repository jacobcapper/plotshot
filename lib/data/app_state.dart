import 'package:flutter/foundation.dart';

import '../logic/dates.dart';
import '../logic/pk.dart';
import '../logic/schedule.dart';
import '../logic/sites.dart';
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
    _changed(reschedule: true);
  }

  void _changed({bool reschedule = false}) {
    _levels = null;
    notifyListeners();
    if (reschedule) {
      rescheduleReminder();
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

  WeightEntry? get latestWeight => weights.isEmpty ? null : weights.last;

  WeightEntry? weightOn(DateTime day) =>
      weights.where((w) => sameDay(w.date, day)).firstOrNull;

  DayLog dayLog(DateTime day) => dayLogs[dayKey(day)] ?? DayLog(date: day);

  List<Jab> jabsOn(DateTime day) =>
      jabs.where((j) => sameDay(j.takenAt, day)).toList();

  /// The medication whose level is headlined: the one used most recently.
  Medication? get primaryMedication => medication(lastJab?.medicationId);

  double currentLevel([DateTime? at]) {
    final med = primaryMedication;
    if (med == null) return 0;
    return levels.levelAt(med.id!, at ?? DateTime.now());
  }

  NextJabInfo nextJab([DateTime? now]) => NextJabInfo.compute(
    lastJab,
    settings.daysBetweenJabs,
    now ?? DateTime.now(),
  );

  Medication? get nextMedication =>
      medication(settings.nextMedicationId) ??
      medication(lastJab?.medicationId) ??
      medications.firstOrNull;

  double? get nextDose {
    final med = nextMedication;
    if (med == null) return null;
    if (settings.nextDoseMg != null) return settings.nextDoseMg;
    if (lastJab != null && lastJab!.medicationId == med.id) {
      return lastJab!.doseMg;
    }
    return med.doses.firstOrNull;
  }

  String? get nextSiteSuggestion => nextSite(settings.rotation, lastJab?.site);

  // ---- Jabs ----

  Future<void> saveJab(Jab jab) async {
    final saved = await _db.saveJab(jab);
    jabs = [...jabs.where((j) => j.id != saved.id), saved]
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    // A newly logged latest jab consumes any planned next-dose change.
    if (jab.id == null && identical(jabs.last, saved)) {
      settings.nextDoseMg = null;
      settings.nextMedicationId = null;
      await settings.save();
    }
    _changed(reschedule: true);
  }

  Future<void> deleteJab(Jab jab) async {
    await _db.deleteJab(jab.id!);
    jabs = jabs.where((j) => j.id != jab.id).toList();
    _changed(reschedule: true);
  }

  Future<void> setNextDose(int medicationId, double doseMg) async {
    settings.nextMedicationId = medicationId;
    settings.nextDoseMg = doseMg;
    await settings.save();
    _changed();
  }

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

  Future<void> saveMedication(Medication m) async {
    final saved = await _db.saveMedication(m);
    medications = [...medications.where((e) => e.id != saved.id), saved]
      ..sort((a, b) => a.id!.compareTo(b.id!));
    _changed();
  }

  bool medicationInUse(Medication m) => jabs.any((j) => j.medicationId == m.id);

  Future<void> deleteMedication(Medication m) async {
    if (medicationInUse(m)) {
      throw StateError('${m.name} has jabs logged against it');
    }
    await _db.deleteMedication(m.id!);
    medications = medications.where((e) => e.id != m.id).toList();
    if (settings.nextMedicationId == m.id) {
      settings.nextMedicationId = null;
      settings.nextDoseMg = null;
      await settings.save();
    }
    _changed();
  }

  // ---- Settings ----

  Future<void> updateSettings(void Function(Settings s) change) async {
    change(settings);
    await settings.save();
    _changed(reschedule: true);
  }

  /// How many daily follow-ups to send if a jab day is missed.
  static const missedJabFollowUps = 3;

  Future<void> rescheduleReminder() async {
    try {
      final next = nextJab();
      if (!settings.remindersEnabled || next.due == null) {
        await notifications.cancelReminders();
        return;
      }
      await notifications.scheduleReminders(
        reminderTimes(next.due!, DateTime.now()),
        title: 'Jab day',
        body: _reminderBody(),
      );
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

  String _reminderBody() {
    final med = nextMedication;
    final dose = nextDose;
    if (med == null) return 'Time for your next jab.';
    return 'Time for your ${med.name}${dose == null ? '' : ' ${_fmt(dose)} mg'} jab.';
  }

  static String _fmt(double d) =>
      d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();

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
    settings.nextDoseMg = null;
    settings.nextMedicationId = null;
    await settings.save();
    await load();
  }
}
