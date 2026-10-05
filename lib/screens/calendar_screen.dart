import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/dates.dart';
import '../logic/units.dart';
import '../models/medication.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/day_editors.dart';
import 'jab_editor_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _goToday();
  }

  void _goToday() {
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dateOnly(now);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(
            onPressed: () => setState(_goToday),
            child: const Text('Today'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() > 200) _shiftMonth(v < 0 ? 1 : -1);
            },
            child: _MonthGrid(
              month: _month,
              selected: _selected,
              state: state,
              onSelect: (d) => setState(() => _selected = d),
            ),
          ),
          const SizedBox(height: 8),
          _DayPanel(day: _selected, state: state),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final AppState state;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.state,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final jabDays = state.jabs.map((j) => dayKey(j.takenAt)).toSet();
    final weightDays = state.weights.map((w) => dayKey(w.date)).toSet();
    final logDays = state.dayLogs.keys.toSet();
    final now = DateTime.now();
    final dueDays = {
      for (final m in state.scheduledMedications)
        if (state.nextJab(m, now).due case final due?) dayKey(due),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: () {
                      final n = r * 7 + c - lead + 1;
                      if (n < 1 || n > daysInMonth) {
                        return const SizedBox(height: 52);
                      }
                      final day = DateTime(month.year, month.month, n);
                      final k = dayKey(day);
                      return _DayCell(
                        day: day,
                        isToday: day == today,
                        isSelected: day == selected,
                        hasJab: jabDays.contains(k),
                        hasWeight: weightDays.contains(k),
                        hasLog: logDays.contains(k),
                        isDue: dueDays.contains(k),
                        onTap: () => onSelect(day),
                      );
                    }(),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday, isSelected, hasJab, hasWeight, hasLog, isDue;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasJab,
    required this.hasWeight,
    required this.hasLog,
    required this.isDue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasJab
                    ? AppColors.accent.withValues(alpha: isSelected ? 1 : 0.25)
                    : (isSelected ? AppColors.cardHigh : null),
                border: isToday
                    ? Border.all(color: AppColors.accent, width: 2)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: hasJab && isSelected
                      ? AppColors.onAccent
                      : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDue && !hasJab) _dot(AppColors.accent),
                if (hasWeight) _dot(AppColors.warning),
                if (hasLog) _dot(AppColors.level),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

class _DayPanel extends StatelessWidget {
  final DateTime day;
  final AppState state;
  const _DayPanel({required this.day, required this.state});

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final title = day == today
        ? 'Today, ${DateFormat('d MMMM').format(day)}'
        : DateFormat('EEEE, d MMMM').format(day);
    final jabs = state.jabsOn(day);
    final w = state.weightOn(day);
    final log = state.dayLog(day);
    final unit = state.settings.weightUnit;
    // Level at the end of the day for past days, or now for today.
    final at = day == today
        ? DateTime.now()
        : DateTime(day.year, day.month, day.day, 23, 59);
    final levels = [
      for (final m in state.medicationsInUse) (m, state.levelOf(m, at)),
    ].where((e) => e.$2 >= 0.005).toList();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          // Several medications' levels need the full width to stay legible.
          if (levels.length > 1) ...[
            _jabCard(context, jabs),
            const SizedBox(height: 10),
            _levelCard(levels),
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: _jabCard(context, jabs)),
                  const SizedBox(width: 10),
                  Expanded(child: _levelCard(levels)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          StatGrid(
            children: [
              StatCard(
                icon: Icons.monitor_weight_outlined,
                iconColor: AppColors.warning,
                label: 'Weight',
                value: w == null ? '—' : formatWeight(w.kg, unit),
                onTap: () => editWeight(context, state, day),
              ),
              StatCard(
                icon: Icons.local_fire_department_outlined,
                iconColor: const Color(0xFFFB923C),
                label: 'Calories',
                value: log.calories?.toString() ?? '—',
                onTap: () => editCalories(context, state, day),
              ),
              StatCard(
                icon: Icons.egg_alt_outlined,
                iconColor: AppColors.danger,
                label: 'Protein',
                value: log.proteinG == null
                    ? '—'
                    : '${log.proteinG!.toStringAsFixed(0)} g',
                onTap: () => editProtein(context, state, day),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _textCard(
            'Side effects',
            log.sideEffects.isEmpty
                ? 'Tap to add side effects'
                : log.sideEffects.join(', '),
            () => editSideEffects(context, state, day),
          ),
          const SizedBox(height: 10),
          _textCard(
            'Notes for day',
            log.notes ?? 'Tap to add notes',
            () => editNotes(context, state, day),
          ),
        ],
      ),
    );
  }

  Widget _jabCard(BuildContext context, List jabs) {
    if (jabs.isEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final now = DateTime.now();
            JabEditorScreen.open(
              context,
              initialDate: DateTime(
                day.year,
                day.month,
                day.day,
                now.hour,
                now.minute,
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vaccines, size: 16, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text(
                      'Jab',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text('Tap to add jab', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final j in jabs)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => JabEditorScreen.open(context, jab: j),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.vaccines,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Jab · ${DateFormat('HH:mm').format(j.takenAt)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${state.medication(j.medicationId)?.name ?? '?'} '
                      '${formatDose(j.doseMg)} mg',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (j.site != null)
                      Text(
                        j.site!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _levelCard(List<(Medication, double)> levels) {
    if (levels.length <= 1) {
      final v = levels.firstOrNull?.$2;
      return StatCard(
        icon: Icons.ssid_chart,
        iconColor: AppColors.level,
        label: 'Est. level',
        value: v == null ? '—' : v.toStringAsFixed(2),
        unit: v == null ? null : 'mg',
      );
    }
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.ssid_chart, size: 16, color: AppColors.level),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Est. level',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final (m, v) in levels)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${v.toStringAsFixed(2)} mg ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: m.name,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _textCard(String label, String text, VoidCallback onTap) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
