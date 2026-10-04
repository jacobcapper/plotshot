import 'package:health/health.dart';

import '../logic/dates.dart';
import '../models/weight_entry.dart';

class DailyNutrition {
  final DateTime date;
  final int? calories;
  final double? proteinG;
  DailyNutrition(this.date, this.calories, this.proteinG);
}

class HealthData {
  final List<WeightEntry> weights;
  final List<DailyNutrition> nutrition;
  HealthData(this.weights, this.nutrition);
}

enum HealthAvailability { available, needsInstallOrUpdate, unsupported }

abstract class HealthService {
  Future<HealthAvailability> availability();
  Future<void> installHealthConnect();

  /// Requests read access. Returns whether it was granted.
  Future<bool> requestAccess();
  Future<HealthData> read(DateTime start, DateTime end);
}

class HealthConnectService implements HealthService {
  static const _types = [HealthDataType.WEIGHT, HealthDataType.NUTRITION];
  final _health = Health();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> availability() async {
    await _configure();
    final status = await _health.getHealthConnectSdkStatus();
    return switch (status) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthAvailability.needsInstallOrUpdate,
      _ => HealthAvailability.unsupported,
    };
  }

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<bool> requestAccess() async {
    await _configure();
    final granted = await _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (granted) {
      // Lets the first sync see data older than 30 days. Not fatal if refused.
      try {
        await _health.requestHealthDataHistoryAuthorization();
      } catch (_) {}
    }
    return granted;
  }

  @override
  Future<HealthData> read(DateTime start, DateTime end) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );

    // Weight: keep the latest reading of each day.
    final latestWeight = <String, HealthDataPoint>{};
    // Nutrition: sum all meals per day.
    final kcal = <String, double>{};
    final protein = <String, double>{};

    for (final p in points) {
      final key = dayKey(p.dateFrom);
      final v = p.value;
      if (p.type == HealthDataType.WEIGHT && v is NumericHealthValue) {
        final prev = latestWeight[key];
        if (prev == null || p.dateFrom.isAfter(prev.dateFrom)) {
          latestWeight[key] = p;
        }
      } else if (p.type == HealthDataType.NUTRITION &&
          v is NutritionHealthValue) {
        if (v.calories != null) kcal[key] = (kcal[key] ?? 0) + v.calories!;
        if (v.protein != null) protein[key] = (protein[key] ?? 0) + v.protein!;
      }
    }

    final weights = latestWeight.entries
        .map(
          (e) => WeightEntry(
            date: parseDayKey(e.key),
            kg: double.parse(
              (e.value.value as NumericHealthValue).numericValue
                  .toDouble()
                  .toStringAsFixed(2),
            ),
            source: 'health_connect',
          ),
        )
        .toList();
    final days = {...kcal.keys, ...protein.keys};
    final nutrition = days
        .map(
          (k) => DailyNutrition(
            parseDayKey(k),
            kcal[k]?.round(),
            protein[k] == null
                ? null
                : double.parse(protein[k]!.toStringAsFixed(1)),
          ),
        )
        .toList();
    return HealthData(weights, nutrition);
  }
}
