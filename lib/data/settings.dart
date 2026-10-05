import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/units.dart';

enum SummarySection { jabHistory, levels, nextJab, today, results, journey }

String summarySectionTitle(SummarySection s) => switch (s) {
  SummarySection.jabHistory => 'Jab History',
  SummarySection.levels => 'Estimated Medication Levels',
  SummarySection.nextJab => 'Next Jab',
  SummarySection.today => 'Today',
  SummarySection.results => 'Results',
  SummarySection.journey => 'Journey',
};

/// User preferences, persisted with shared_preferences. Dosing schedules
/// live on each [Medication], not here.
class Settings {
  WeightUnit weightUnit;
  HeightUnit heightUnit;
  double? heightCm;
  double? goalKg;

  bool remindersEnabled;
  TimeOfDay reminderTime;

  bool healthConnectEnabled;
  DateTime? lastHealthSync;

  List<SummarySection> summaryOrder;
  Set<SummarySection> summaryHidden;

  /// Medication whose doses colour the weight chart; null picks automatically.
  int? chartMedicationId;

  /// Schedule values from before they moved onto each medication (v1).
  /// Applied to medications once by [AppState.load], then cleared.
  LegacySchedule? legacy;

  Settings({
    this.weightUnit = WeightUnit.kg,
    this.heightUnit = HeightUnit.cm,
    this.heightCm,
    this.goalKg,
    this.remindersEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
    this.healthConnectEnabled = false,
    this.lastHealthSync,
    List<SummarySection>? summaryOrder,
    Set<SummarySection>? summaryHidden,
    this.chartMedicationId,
    this.legacy,
  }) : summaryOrder = summaryOrder ?? [...SummarySection.values],
       summaryHidden = summaryHidden ?? {};

  static List<SummarySection> _order(Iterable<Object?> names) {
    final order = names
        .map((n) => SummarySection.values.where((s) => s.name == n).firstOrNull)
        .whereType<SummarySection>()
        .toList();
    // Sections added in later versions go at the end.
    for (final s in SummarySection.values) {
      if (!order.contains(s)) order.add(s);
    }
    return order;
  }

  static Set<SummarySection> _hidden(Iterable<Object?> names) => names
      .map((n) => SummarySection.values.where((s) => s.name == n).firstOrNull)
      .whereType<SummarySection>()
      .toSet();

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    T byName<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    final sync = p.getInt('lastHealthSync');
    return Settings(
      weightUnit: byName(
        WeightUnit.values,
        p.getString('weightUnit'),
        WeightUnit.kg,
      ),
      heightUnit: byName(
        HeightUnit.values,
        p.getString('heightUnit'),
        HeightUnit.cm,
      ),
      heightCm: p.getDouble('heightCm'),
      goalKg: p.getDouble('goalKg'),
      remindersEnabled: p.getBool('remindersEnabled') ?? false,
      reminderTime: TimeOfDay(
        hour: p.getInt('reminderHour') ?? 9,
        minute: p.getInt('reminderMinute') ?? 0,
      ),
      healthConnectEnabled: p.getBool('healthConnectEnabled') ?? false,
      lastHealthSync: sync == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(sync),
      summaryOrder: _order(p.getStringList('summaryOrder') ?? []),
      summaryHidden: _hidden(p.getStringList('summaryHidden') ?? []),
      chartMedicationId: p.getInt('chartMedicationId'),
      legacy: LegacySchedule.fromPrefs(p),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    Future<void> setOrRemoveDouble(String k, double? v) =>
        v == null ? p.remove(k) : p.setDouble(k, v);
    await p.setString('weightUnit', weightUnit.name);
    await p.setString('heightUnit', heightUnit.name);
    await setOrRemoveDouble('heightCm', heightCm);
    await setOrRemoveDouble('goalKg', goalKg);
    await p.setBool('remindersEnabled', remindersEnabled);
    await p.setInt('reminderHour', reminderTime.hour);
    await p.setInt('reminderMinute', reminderTime.minute);
    await p.setBool('healthConnectEnabled', healthConnectEnabled);
    if (lastHealthSync == null) {
      await p.remove('lastHealthSync');
    } else {
      await p.setInt('lastHealthSync', lastHealthSync!.millisecondsSinceEpoch);
    }
    await p.setStringList(
      'summaryOrder',
      summaryOrder.map((s) => s.name).toList(),
    );
    await p.setStringList(
      'summaryHidden',
      summaryHidden.map((s) => s.name).toList(),
    );
    if (chartMedicationId == null) {
      await p.remove('chartMedicationId');
    } else {
      await p.setInt('chartMedicationId', chartMedicationId!);
    }
    if (legacy == null) {
      for (final k in LegacySchedule.keys) {
        await p.remove(k);
      }
    }
  }

  Map<String, Object?> toJson() => {
    'weightUnit': weightUnit.name,
    'heightUnit': heightUnit.name,
    'heightCm': heightCm,
    'goalKg': goalKg,
    'remindersEnabled': remindersEnabled,
    'reminderHour': reminderTime.hour,
    'reminderMinute': reminderTime.minute,
    'summaryOrder': summaryOrder.map((s) => s.name).toList(),
    'summaryHidden': summaryHidden.map((s) => s.name).toList(),
  };

  /// Applies settings from a backup, ignoring anything unrecognised.
  void applyJson(Map<String, Object?> j) {
    T? byName<T extends Enum>(List<T> values, Object? name) =>
        values.where((v) => v.name == name).firstOrNull;
    weightUnit = byName(WeightUnit.values, j['weightUnit']) ?? weightUnit;
    heightUnit = byName(HeightUnit.values, j['heightUnit']) ?? heightUnit;
    heightCm = (j['heightCm'] as num?)?.toDouble();
    goalKg = (j['goalKg'] as num?)?.toDouble();
    remindersEnabled = j['remindersEnabled'] as bool? ?? remindersEnabled;
    reminderTime = TimeOfDay(
      hour: (j['reminderHour'] as num?)?.toInt() ?? reminderTime.hour,
      minute: (j['reminderMinute'] as num?)?.toInt() ?? reminderTime.minute,
    );
    if (j['summaryOrder'] is List) {
      summaryOrder = _order(j['summaryOrder'] as List);
    }
    if (j['summaryHidden'] is List) {
      summaryHidden = _hidden(j['summaryHidden'] as List);
    }
    chartMedicationId = null;
  }
}

/// The global schedule settings used before v2, when every medication shared
/// one interval and one site rotation.
class LegacySchedule {
  static const keys = [
    'daysBetweenJabs',
    'rotation',
    'nextDoseMg',
    'nextMedicationId',
  ];

  final int? daysBetweenJabs;
  final List<String>? rotation;
  final double? nextDoseMg;
  final int? nextMedicationId;

  LegacySchedule({
    this.daysBetweenJabs,
    this.rotation,
    this.nextDoseMg,
    this.nextMedicationId,
  });

  static LegacySchedule? fromPrefs(SharedPreferences p) {
    if (!keys.any(p.containsKey)) return null;
    return LegacySchedule(
      daysBetweenJabs: p.getInt('daysBetweenJabs'),
      rotation: p.getStringList('rotation'),
      nextDoseMg: p.getDouble('nextDoseMg'),
      nextMedicationId: p.getInt('nextMedicationId'),
    );
  }

  /// A v1 backup's settings block carries the same values.
  static LegacySchedule? fromJson(Map<String, Object?> j) {
    if (!j.containsKey('daysBetweenJabs') && !j.containsKey('rotation')) {
      return null;
    }
    return LegacySchedule(
      daysBetweenJabs: (j['daysBetweenJabs'] as num?)?.toInt(),
      rotation: (j['rotation'] as List?)?.whereType<String>().toList(),
    );
  }
}
