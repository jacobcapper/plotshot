import 'dart:math';

import '../logic/stats.dart';
import '../logic/units.dart';
import 'app_state.dart';

/// What the home screen widgets show. Due times are sent as instants, not
/// labels, so a widget can say "Due tomorrow" or "Due today" as days pass
/// without the app running. Weights are formatted in the user's unit here.
Map<String, Object?> widgetData(AppState state) => {
  'jabs': [
    for (final m in state.scheduledMedications)
      {
        'medicationId': m.id,
        'name': m.name,
        'due': state.nextJab(m).due?.millisecondsSinceEpoch,
        'dose': switch (state.nextDose(m)) {
          null => null,
          final d => '${formatDose(d)} mg',
        },
        'site': state.nextSiteFor(m),
      },
  ],
  'goal': goalWidgetData(
    WeightStats.compute(state.weights),
    state.settings.goalKg,
    state.settings.weightUnit,
  ),
};

/// Progress towards the goal weight. `state` is `noGoal`, `noWeight` or
/// `tracking`.
Map<String, Object?> goalWidgetData(
  WeightStats? stats,
  double? goalKg,
  WeightUnit unit,
) {
  if (goalKg == null) return {'state': 'noGoal'};
  if (stats == null) {
    return {'state': 'noWeight', 'goal': formatWeight(goalKg, unit)};
  }
  final losing = stats.journeyStartKg >= goalKg;
  final reached = losing
      ? stats.currentKg <= goalKg
      : stats.currentKg >= goalKg;
  final (left, leftUnit) = weightParts((stats.currentKg - goalKg).abs(), unit);
  return {
    'state': 'tracking',
    // Rounded like the Results screen, but only 100 once actually reached.
    'percent': reached
        ? 100
        : min(99, (stats.goalProgress(goalKg) ?? 0).round()),
    'reached': reached,
    'toGo': '$left $leftUnit',
    'start': formatWeight(stats.journeyStartKg, unit),
    'current': formatWeight(stats.currentKg, unit),
    'goal': formatWeight(goalKg, unit),
  };
}
