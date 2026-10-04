import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/sites.dart';
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

/// User preferences, persisted with shared_preferences.
class Settings {
  WeightUnit weightUnit;
  HeightUnit heightUnit;
  double? heightCm;
  double? goalKg;
  int daysBetweenJabs;

  /// Enabled sites, in rotation order.
  List<String> rotation;

  bool remindersEnabled;
  TimeOfDay reminderTime;

  bool healthConnectEnabled;
  DateTime? lastHealthSync;

  List<SummarySection> summaryOrder;
  Set<SummarySection> summaryHidden;

  /// Dose chosen for the next jab, if the user changed it from the last dose.
  double? nextDoseMg;
  int? nextMedicationId;

  Settings({
    this.weightUnit = WeightUnit.kg,
    this.heightUnit = HeightUnit.cm,
    this.heightCm,
    this.goalKg,
    this.daysBetweenJabs = 7,
    List<String>? rotation,
    this.remindersEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
    this.healthConnectEnabled = false,
    this.lastHealthSync,
    List<SummarySection>? summaryOrder,
    Set<SummarySection>? summaryHidden,
    this.nextDoseMg,
    this.nextMedicationId,
  }) : rotation = rotation ?? [...defaultRotation],
       summaryOrder = summaryOrder ?? [...SummarySection.values],
       summaryHidden = summaryHidden ?? {};

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    T byName<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    final order = (p.getStringList('summaryOrder') ?? [])
        .map((n) => SummarySection.values.where((s) => s.name == n).firstOrNull)
        .whereType<SummarySection>()
        .toList();
    // Sections added in later versions go at the end.
    for (final s in SummarySection.values) {
      if (!order.contains(s)) order.add(s);
    }
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
      daysBetweenJabs: p.getInt('daysBetweenJabs') ?? 7,
      rotation: p.getStringList('rotation'),
      remindersEnabled: p.getBool('remindersEnabled') ?? false,
      reminderTime: TimeOfDay(
        hour: p.getInt('reminderHour') ?? 9,
        minute: p.getInt('reminderMinute') ?? 0,
      ),
      healthConnectEnabled: p.getBool('healthConnectEnabled') ?? false,
      lastHealthSync: sync == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(sync),
      summaryOrder: order,
      summaryHidden: (p.getStringList('summaryHidden') ?? [])
          .map(
            (n) => SummarySection.values.where((s) => s.name == n).firstOrNull,
          )
          .whereType<SummarySection>()
          .toSet(),
      nextDoseMg: p.getDouble('nextDoseMg'),
      nextMedicationId: p.getInt('nextMedicationId'),
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
    await p.setInt('daysBetweenJabs', daysBetweenJabs);
    await p.setStringList('rotation', rotation);
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
    await setOrRemoveDouble('nextDoseMg', nextDoseMg);
    if (nextMedicationId == null) {
      await p.remove('nextMedicationId');
    } else {
      await p.setInt('nextMedicationId', nextMedicationId!);
    }
  }

  Map<String, Object?> toJson() => {
    'weightUnit': weightUnit.name,
    'heightUnit': heightUnit.name,
    'heightCm': heightCm,
    'goalKg': goalKg,
    'daysBetweenJabs': daysBetweenJabs,
    'rotation': rotation,
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
    daysBetweenJabs =
        (j['daysBetweenJabs'] as num?)?.toInt() ?? daysBetweenJabs;
    if (j['rotation'] is List) {
      rotation = (j['rotation'] as List).whereType<String>().toList();
    }
    remindersEnabled = j['remindersEnabled'] as bool? ?? remindersEnabled;
    reminderTime = TimeOfDay(
      hour: (j['reminderHour'] as num?)?.toInt() ?? reminderTime.hour,
      minute: (j['reminderMinute'] as num?)?.toInt() ?? reminderTime.minute,
    );
    if (j['summaryOrder'] is List) {
      final order = (j['summaryOrder'] as List)
          .map((n) => byName(SummarySection.values, n))
          .whereType<SummarySection>()
          .toList();
      for (final s in SummarySection.values) {
        if (!order.contains(s)) order.add(s);
      }
      summaryOrder = order;
    }
    if (j['summaryHidden'] is List) {
      summaryHidden = (j['summaryHidden'] as List)
          .map((n) => byName(SummarySection.values, n))
          .whereType<SummarySection>()
          .toSet();
    }
  }
}
