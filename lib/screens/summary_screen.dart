import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/settings.dart';
import '../logic/dates.dart';
import '../logic/stats.dart';
import '../logic/units.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/day_editors.dart';
import '../widgets/level_chart.dart';
import '../widgets/next_jab_card.dart';
import 'home_shell.dart';
import 'jab_editor_screen.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final sections = s.summaryOrder.where((x) => !s.summaryHidden.contains(x));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Customise summary',
          icon: const Icon(Icons.tune),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _SummarySettingsSheet(),
          ),
        ),
        title: const Text('Summary'),
        actions: [
          TextButton.icon(
            onPressed: () => JabEditorScreen.open(context),
            icon: const Icon(Icons.add),
            label: const Text('Add jab'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          for (final section in sections) _section(section),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyHint(
                icon: Icons.visibility_off_outlined,
                text:
                    'All sections are hidden. Tap the controls icon to '
                    'show some.',
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(SummarySection s) => switch (s) {
    SummarySection.jabHistory => const _JabHistorySection(),
    SummarySection.levels => const _LevelsSection(),
    SummarySection.nextJab => const Column(
      children: [SectionHeader('Next Jab'), NextJabCard()],
    ),
    SummarySection.today => const _TodaySection(),
    SummarySection.results => const _ResultsSection(),
    SummarySection.journey => const _JourneySection(),
  };
}

Widget _seeAll(BuildContext context, int tab) => TextButton(
  onPressed: () => HomeShell.goToTab(context, tab),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [Text('See all'), Icon(Icons.chevron_right, size: 20)],
  ),
);

class _JabHistorySection extends StatelessWidget {
  const _JabHistorySection();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final last = state.lastJab;
    return Column(
      children: [
        SectionHeader('Jab History', trailing: _seeAll(context, 1)),
        StatGrid(
          children: [
            StatCard(
              icon: Icons.vaccines,
              label: 'Jabs taken',
              value: '${state.jabs.length}',
            ),
            StatCard(
              icon: Icons.medication,
              label: 'Last dose',
              value: last == null ? '—' : formatDose(last.doseMg),
              unit: last == null ? null : 'mg',
            ),
            StatCard(
              icon: Icons.ssid_chart,
              iconColor: AppColors.level,
              label: 'Est. level',
              value: last == null
                  ? '—'
                  : state.currentLevel().toStringAsFixed(2),
              unit: last == null ? null : 'mg',
            ),
          ],
        ),
      ],
    );
  }
}

class _LevelsSection extends StatefulWidget {
  const _LevelsSection();
  @override
  State<_LevelsSection> createState() => _LevelsSectionState();
}

class _LevelsSectionState extends State<_LevelsSection> {
  static const _ranges = {'2W': 14, '1M': 30, '3M': 90, 'All': -1};
  String _range = '1M';
  int? _medId;

  void _explain(BuildContext context) => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('How levels are estimated'),
      content: const SingleChildScrollView(
        child: Text(
          'Each jab is modelled as a dose that is absorbed from the '
          'injection site, peaks, then clears at the rate set by the '
          'medication\'s half-life (a one-compartment model with '
          'first-order absorption). The curve is the total of all your '
          'jabs added together.\n\n'
          'The dashed section projects forward assuming no further jabs.\n\n'
          'Half-life and time to peak can be changed per medication in '
          'Settings → Medications.\n\n'
          'This is an estimate for interest only, not medical advice. Real '
          'levels vary from person to person.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final inUse = state.levels.medicationsInUse();
    final medId = inUse.contains(_medId)
        ? _medId
        : (inUse.isEmpty ? null : inUse.first);
    final now = DateTime.now();

    Widget body;
    if (medId == null) {
      body = EmptyHint(
        icon: Icons.ssid_chart,
        text: 'Log a jab to see your estimated medication level.',
        action: FilledButton(
          onPressed: () => JabEditorScreen.open(context),
          child: const Text('Add jab'),
        ),
      );
    } else {
      final medJabs = state.jabs.where((j) => j.medicationId == medId).toList();
      final days = _ranges[_range]!;
      final start = days < 0
          ? medJabs.first.takenAt.subtract(const Duration(hours: 12))
          : now.subtract(Duration(days: days));
      final end = now.add(
        Duration(days: days < 0 ? 14 : (days / 4).ceil().clamp(4, 14)),
      );
      final spanHours = end.difference(start).inHours;
      final step = Duration(hours: (spanHours / 240).ceil().clamp(1, 24));
      final points = state.levels.series(medId, start, end, step: step);
      final med = state.medication(medId)!;
      final peak = medJabs.isEmpty
          ? 0.0
          : state.levels.levelAt(
              medId,
              medJabs.last.takenAt.add(
                Duration(minutes: (med.timeToPeakDays * 24 * 60).round()),
              ),
            );
      body = Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: inUse.length > 1
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: DropdownButton<int>(
                              value: medId,
                              isDense: true,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final id in inUse)
                                  DropdownMenuItem(
                                    value: id,
                                    child: Text(
                                      state.medication(id)?.name ?? '?',
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _medId = v),
                            ),
                          )
                        : Text(
                            med.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                  const SizedBox(width: 8),
                  _RangePicker(
                    options: _ranges.keys.toList(),
                    selected: _range,
                    onChanged: (r) => setState(() => _range = r),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LevelChart(points: points, now: now, jabs: medJabs),
              const SizedBox(height: 8),
              Row(
                children: [
                  _legend(
                    'Now',
                    '${state.levels.levelAt(medId, now).toStringAsFixed(2)} mg',
                  ),
                  _legend(
                    'Peak after last jab',
                    '${peak.toStringAsFixed(2)} mg',
                  ),
                  _legend('Half-life', '${formatDose(med.halfLifeDays)} d'),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        SectionHeader(
          'Estimated Medication Levels',
          titleTrailing: IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.accent,
              size: 20,
            ),
            onPressed: () => _explain(context),
          ),
        ),
        body,
      ],
    );
  }

  Widget _legend(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _TodaySection extends StatelessWidget {
  const _TodaySection();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = dateOnly(DateTime.now());
    final w = state.weightOn(today);
    final log = state.dayLog(today);
    final unit = state.settings.weightUnit;
    return Column(
      children: [
        SectionHeader(
          'Today',
          trailing: Text(
            DateFormat('EEE d MMM').format(today),
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
        StatGrid(
          children: [
            StatCard(
              icon: Icons.monitor_weight_outlined,
              iconColor: AppColors.warning,
              label: 'Weight',
              value: w == null ? 'Add' : formatWeight(w.kg, unit),
              onTap: () => editWeight(context, state, today),
            ),
            StatCard(
              icon: Icons.local_fire_department_outlined,
              iconColor: const Color(0xFFFB923C),
              label: 'Calories',
              value: log.calories?.toString() ?? 'Add',
              unit: log.calories == null ? null : ' kcal',
              onTap: () => editCalories(context, state, today),
            ),
            StatCard(
              icon: Icons.egg_alt_outlined,
              iconColor: AppColors.danger,
              label: 'Protein',
              value: log.proteinG?.toStringAsFixed(0) ?? 'Add',
              unit: log.proteinG == null ? null : ' g',
              onTap: () => editProtein(context, state, today),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.sick_outlined),
            title: const Text('Side effects'),
            subtitle: Text(
              log.sideEffects.isEmpty
                  ? 'Tap to add'
                  : log.sideEffects.join(', '),
            ),
            onTap: () => editSideEffects(context, state, today),
          ),
        ),
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = WeightStats.compute(state.weights);
    final unit = state.settings.weightUnit;
    final goal = state.settings.goalKg;
    Widget body;
    if (stats == null) {
      body = EmptyHint(
        icon: Icons.monitor_weight_outlined,
        text: 'Log your weight to track results.',
        action: FilledButton(
          onPressed: () => editWeight(context, state, DateTime.now()),
          child: const Text('Log weight'),
        ),
      );
    } else {
      final (cv, cu) = weightParts(stats.changeKg, unit, signed: true);
      final (gv, gu) = goal == null
          ? ('—', '')
          : weightParts(stats.toGoalKg(goal), unit);
      body = StatGrid(
        children: [
          StatCard(
            icon: Icons.trending_down,
            label: 'Total change',
            value: cv,
            unit: cu,
          ),
          StatCard(
            icon: Icons.percent,
            label: 'Percent',
            value: stats.percentChange.toStringAsFixed(1),
            unit: '%',
          ),
          StatCard(
            icon: Icons.flag_outlined,
            label: 'To goal',
            value: gv,
            unit: gu,
          ),
        ],
      );
    }
    return Column(
      children: [
        SectionHeader('Results', trailing: _seeAll(context, 2)),
        body,
      ],
    );
  }
}

class _JourneySection extends StatelessWidget {
  const _JourneySection();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unit = state.settings.weightUnit;
    final goal = state.settings.goalKg;
    final stats = WeightStats.compute(state.weights);
    final firstJab = state.jabs.isEmpty ? null : state.jabs.first.takenAt;
    final weeks = firstJab == null
        ? null
        : calendarDaysBetween(firstJab, DateTime.now()) ~/ 7;
    final progress = stats == null || goal == null
        ? null
        : stats.goalProgress(goal);
    return Column(
      children: [
        const SectionHeader('Journey'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _point(
                      'Start',
                      stats == null
                          ? '—'
                          : formatWeight(stats.journeyStartKg, unit),
                    ),
                    _point(
                      'Now',
                      stats == null ? '—' : formatWeight(stats.currentKg, unit),
                    ),
                    _point(
                      'Goal',
                      goal == null
                          ? 'Set in Settings'
                          : formatWeight(goal, unit),
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 10,
                      backgroundColor: AppColors.cardHigh,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${progress.toStringAsFixed(0)}% of the way to your goal',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                if (weeks != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    weeks == 0
                        ? 'Started ${DateFormat('d MMM yyyy').format(firstJab!)}'
                        : '$weeks week${weeks == 1 ? '' : 's'} since your first jab '
                              '(${DateFormat('d MMM yyyy').format(firstJab!)})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _point(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _SummarySettingsSheet extends StatelessWidget {
  const _SummarySettingsSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 60),
                const Expanded(
                  child: Text(
                    'Summary Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 0, 8),
                child: Text(
                  'Order & visibility',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => state.updateSettings((st) {
                  final item = st.summaryOrder.removeAt(from);
                  st.summaryOrder.insert(to, item);
                }),
                children: [
                  for (var i = 0; i < s.summaryOrder.length; i++)
                    Padding(
                      key: ValueKey(s.summaryOrder[i]),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: IconButton(
                            icon: Icon(
                              s.summaryHidden.contains(s.summaryOrder[i])
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility,
                              color: s.summaryHidden.contains(s.summaryOrder[i])
                                  ? AppColors.muted
                                  : AppColors.text,
                            ),
                            onPressed: () => state.updateSettings((st) {
                              final sec = st.summaryOrder[i];
                              st.summaryHidden.contains(sec)
                                  ? st.summaryHidden.remove(sec)
                                  : st.summaryHidden.add(sec);
                            }),
                          ),
                          title: Text(
                            summarySectionTitle(s.summaryOrder[i]),
                            style: TextStyle(
                              color: s.summaryHidden.contains(s.summaryOrder[i])
                                  ? AppColors.muted
                                  : AppColors.text,
                            ),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(
                              Icons.drag_handle,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill-style range selector that fits beside a title.
class _RangePicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _RangePicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: o == selected ? AppColors.accent : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: o == selected ? AppColors.onAccent : AppColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
