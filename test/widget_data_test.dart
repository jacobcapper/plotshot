import 'package:flutter_test/flutter_test.dart';
import 'package:plotshot/data/widget_data.dart';
import 'package:plotshot/logic/stats.dart';
import 'package:plotshot/logic/units.dart';
import 'package:plotshot/models/weight_entry.dart';
import 'package:plotshot/services/widget_service.dart';

import 'support/fixtures.dart';

class RecordingWidgets extends NoopWidgetService {
  Map<String, Object?>? data;
  @override
  Future<void> update(Map<String, Object?> data) async => this.data = data;
}

WeightStats stats(List<double> kgs) => WeightStats.compute([
  for (final (i, kg) in kgs.indexed)
    WeightEntry(date: DateTime(2026, 1, 1 + i), kg: kg),
])!;

void main() {
  test('lists scheduled medications soonest first with due instants', () async {
    final s = await makeState(seed: true);
    final second = await seedSecondMedication(s);
    final jabs = widgetData(s)['jabs'] as List;
    expect(jabs.map((j) => (j as Map)['name']), [
      'Testosterone Enanthate',
      'Retatrutide',
    ]);
    final reta = jabs[1] as Map;
    final med = s.medications.firstWhere((m) => m.name == 'Retatrutide');
    expect(reta['medicationId'], med.id);
    expect(reta['due'], s.nextJab(med).due!.millisecondsSinceEpoch);
    expect(reta['dose'], '6 mg');
    expect(reta['site'], 'Stomach - Lower Mid');
    expect((jabs[0] as Map)['dose'], '75 mg');
    expect((jabs[0] as Map)['medicationId'], second.id);
  });

  test('a fresh install has nothing scheduled and no goal', () async {
    final s = await makeState();
    expect(widgetData(s), {
      'jabs': <Object?>[],
      'goal': {'state': 'noGoal'},
    });
  });

  test('goal progress in the user unit', () async {
    final s = await makeState(seed: true);
    expect(widgetData(s)['goal'], {
      'state': 'tracking',
      'percent': 31, // 7.4 of 23.5 kg
      'reached': false,
      'toGo': '16.1 kg',
      'start': '143.5 kg',
      'current': '136.1 kg',
      'goal': '120.0 kg',
    });
    await s.updateSettings((x) => x.weightUnit = WeightUnit.lb);
    final goal = widgetData(s)['goal'] as Map;
    expect(goal['toGo'], '35.5 lb');
    expect(goal['current'], '300.0 lb');
  });

  test('goal states', () {
    expect(goalWidgetData(null, 80, WeightUnit.kg), {
      'state': 'noWeight',
      'goal': '80.0 kg',
    });
    // Rounds down until the goal is actually reached.
    expect(
      goalWidgetData(stats([100, 80.1]), 80, WeightUnit.kg)['percent'],
      99,
    );
    final reached = goalWidgetData(stats([100, 79]), 80, WeightUnit.kg);
    expect(reached['percent'], 100);
    expect(reached['reached'], isTrue);
    // Gaining towards a goal works the same way.
    final gaining = goalWidgetData(stats([60, 65]), 70, WeightUnit.kg);
    expect(gaining['percent'], 50);
    expect(gaining['toGo'], '5.0 kg');
  });

  test('pushes to the widgets on every change', () async {
    final widgets = RecordingWidgets();
    final state = await makeState(widgets: widgets);
    expect(widgets.data?['goal'], {'state': 'noGoal'});
    await state.updateSettings((x) => x.goalKg = 90);
    expect(widgets.data?['goal'], {'state': 'noWeight', 'goal': '90.0 kg'});
    await state.saveWeight(WeightEntry(date: DateTime.now(), kg: 100));
    expect((widgets.data?['goal'] as Map)['state'], 'tracking');
  });
}
