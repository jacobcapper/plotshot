import '../models/day_log.dart';
import '../models/jab.dart';
import '../models/medication.dart';
import '../models/weight_entry.dart';
import 'settings.dart';

class BackupContents {
  final int version;
  final Map<String, Object?> settings;
  final List<Medication> medications;
  final List<Jab> jabs;
  final List<WeightEntry> weights;
  final List<DayLog> dayLogs;

  BackupContents(
    this.version,
    this.settings,
    this.medications,
    this.jabs,
    this.weights,
    this.dayLogs,
  );
}

/// JSON backup format. Rows use the same shape as the database tables.
class Backup {
  static const format = 'plotshot-backup';
  static const version = 2;

  static Map<String, Object?> encode({
    required Settings settings,
    required List<Medication> medications,
    required List<Jab> jabs,
    required List<WeightEntry> weights,
    required List<DayLog> dayLogs,
  }) => {
    'format': format,
    'version': version,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': settings.toJson(),
    'medications': medications.map((m) => m.toMap()).toList(),
    'jabs': jabs.map((j) => j.toMap()).toList(),
    'weights': weights.map((w) => w.toMap()).toList(),
    'dayLogs': dayLogs.map((l) => l.toMap()).toList(),
  };

  static BackupContents decode(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('Not a PlotShot backup file');
    }
    if ((json['version'] as num? ?? 0) > version) {
      throw const FormatException(
        'This backup is from a newer version of PlotShot',
      );
    }
    List<Map<String, Object?>> rows(String key) =>
        ((json[key] as List?) ?? const [])
            .map((e) => Map<String, Object?>.from(e as Map))
            .toList();
    final meds = rows('medications').map(Medication.fromMap).toList();
    final medIds = meds.map((m) => m.id).toSet();
    final jabs = rows('jabs').map(Jab.fromMap).toList();
    if (jabs.any((j) => !medIds.contains(j.medicationId))) {
      throw const FormatException('Backup has jabs for an unknown medication');
    }
    return BackupContents(
      (json['version'] as num? ?? 1).toInt(),
      Map<String, Object?>.from(json['settings'] as Map? ?? const {}),
      meds,
      jabs,
      rows('weights').map(WeightEntry.fromMap).toList(),
      rows('dayLogs').map(DayLog.fromMap).toList(),
    );
  }
}
