import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/stats.dart';
import '../logic/units.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/day_editors.dart';
import '../widgets/weight_chart.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static const _ranges = {
    '1 month': 30,
    '3 months': 91,
    '6 months': 182,
    'All Time': -1,
  };
  String _range = 'All Time';
  bool _showAllWeights = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unit = state.settings.weightUnit;
    final goal = state.settings.goalKg;
    final days = _ranges[_range]!;
    final since = days < 0
        ? null
        : DateTime.now().subtract(Duration(days: days));
    final stats = WeightStats.compute(state.weights, since: since);
    final inRange = since == null
        ? state.weights
        : state.weights.where((w) => !w.date.isBefore(since)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          TextButton.icon(
            onPressed: () => editWeight(context, state, DateTime.now()),
            icon: const Icon(Icons.add),
            label: const Text('Log weight'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionHeader(
            'Weight Change',
            trailing: stats == null
                ? null
                : Text(
                    '${DateFormat('d MMM yy').format(stats.startDate)} – '
                    '${DateFormat('d MMM yy').format(stats.endDate)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
          ),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final r in _ranges.keys)
                ButtonSegment(value: r, label: Text(r, maxLines: 1)),
            ],
            selected: {_range},
            onSelectionChanged: (v) => setState(() => _range = v.first),
          ),
          const SizedBox(height: 14),
          if (stats == null)
            EmptyHint(
              icon: Icons.monitor_weight_outlined,
              text: state.weights.isEmpty
                  ? 'No weights logged yet.'
                  : 'No weights in this range.',
              action: FilledButton(
                onPressed: () => editWeight(context, state, DateTime.now()),
                child: const Text('Log weight'),
              ),
            )
          else ...[
            _statGrid(stats, unit, goal, state.settings.heightCm),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: WeightChart(
                  weights: inRange,
                  jabs: state.jabs,
                  unit: unit,
                  goalKg: goal,
                ),
              ),
            ),
          ],
          if (state.jabs.isNotEmpty) ..._dosages(state, unit),
          if (state.weights.isNotEmpty) ..._weightLog(state, unit),
        ],
      ),
    );
  }

  Widget _statGrid(
    WeightStats s,
    WeightUnit unit,
    double? goal,
    double? heightCm,
  ) {
    final (cv, cu) = weightParts(s.changeKg, unit, decimals: 2, signed: true);
    final weekly = s.weeklyAvgKg;
    final (wv, wu) = weekly == null
        ? ('—', '')
        : weightParts(weekly, unit, decimals: 2, signed: true);
    final (curV, curU) = unit == WeightUnit.st
        ? (formatWeight(s.currentKg, unit), '')
        : weightParts(s.currentKg, unit, decimals: 2);
    final b = bmi(s.currentKg, heightCm);
    String? goalSuffix;
    String goalValue = '—';
    String goalUnit = '';
    if (goal != null) {
      final (gv, gu) = weightParts(s.toGoalKg(goal), unit, decimals: 2);
      goalValue = gv;
      goalUnit = gu;
      final p = s.goalProgress(goal);
      if (p != null) goalSuffix = '(${p.toStringAsFixed(0)}%)';
    }
    return StatGrid(
      children: [
        StatCard(icon: Icons.scale, label: 'Change', value: cv, unit: cu),
        StatCard(
          icon: Icons.accessibility_new,
          label: 'BMI',
          value: b == null ? '—' : b.toStringAsFixed(1),
        ),
        StatCard(
          icon: Icons.monitor_weight_outlined,
          label: 'Weight',
          value: curV,
          unit: curU,
        ),
        StatCard(
          icon: Icons.percent,
          label: 'Percent',
          value: s.percentChange.toStringAsFixed(1),
          unit: '%',
        ),
        StatCard(
          icon: Icons.hourglass_bottom,
          label: 'Weekly avg',
          value: wv,
          unit: wu.isEmpty ? null : '$wu/wk',
        ),
        StatCard(
          icon: Icons.flag,
          label: 'To goal',
          value: goalValue,
          unit: goalUnit,
          suffix: goalSuffix,
        ),
      ],
    );
  }

  List<Widget> _dosages(AppState state, WeightUnit unit) {
    final summaries = doseSummaries(state.jabs, state.weights, DateTime.now());
    final allDoses = state.jabs.map((j) => j.doseMg);
    final fmt = DateFormat('d MMM');
    return [
      const SectionHeader('Dosages'),
      Card(
        child: Column(
          children: [
            for (final (i, d) in summaries.reversed.indexed) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: DoseChip(
                  d.doseMg,
                  color: doseColor(d.doseMg, allDoses),
                ),
                title: Text(
                  '${state.medication(d.medicationId)?.name ?? '?'} · '
                  '${d.jabCount} jab${d.jabCount == 1 ? '' : 's'}',
                ),
                subtitle: Text(
                  d.jabCount == 1
                      ? fmt.format(d.first)
                      : '${fmt.format(d.first)} – ${fmt.format(d.last)}',
                ),
                trailing: d.changeKg == null
                    ? null
                    : Text(
                        () {
                          final (v, u) = weightParts(
                            d.changeKg!,
                            unit,
                            signed: true,
                          );
                          return '$v $u';
                        }(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: d.changeKg! <= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _weightLog(AppState state, WeightUnit unit) {
    final entries = state.weights.reversed.toList();
    final shown = _showAllWeights ? entries : entries.take(10).toList();
    return [
      const SectionHeader('Weight Log'),
      Card(
        child: Column(
          children: [
            for (final (i, w) in shown.indexed) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              ListTile(
                title: Text(formatWeight(w.kg, unit)),
                subtitle: Text(DateFormat('EEE d MMM yyyy').format(w.date)),
                trailing: w.source == 'health_connect'
                    ? const Tooltip(
                        message: 'From Health Connect',
                        child: Icon(
                          Icons.favorite,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      )
                    : null,
                onTap: () => editWeight(context, state, w.date),
              ),
            ],
            if (entries.length > shown.length)
              TextButton(
                onPressed: () => setState(() => _showAllWeights = true),
                child: Text('Show all ${entries.length}'),
              ),
          ],
        ),
      ),
    ];
  }
}
