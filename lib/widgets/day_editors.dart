import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../models/day_log.dart';
import '../models/weight_entry.dart';
import '../theme.dart';
import 'inputs.dart';

/// Editors for the per-day values shown on Summary "Today" and the Calendar.

Future<void> editWeight(
  BuildContext context,
  AppState state,
  DateTime day,
) async {
  final existing = state.weightOn(day);
  final kg = await showWeightDialog(
    context,
    unit: state.settings.weightUnit,
    initialKg: existing?.kg ?? state.latestWeight?.kg,
    title: 'Weight · ${DateFormat('d MMM').format(day)}',
    allowRemove: existing != null,
  );
  if (kg == null) return;
  if (kg < 0) {
    await state.deleteWeight(day);
  } else {
    await state.saveWeight(WeightEntry(date: day, kg: kg));
  }
}

Future<void> editCalories(
  BuildContext context,
  AppState state,
  DateTime day,
) async {
  final log = state.dayLog(day);
  final v = await showNumberDialog(
    context,
    title: 'Calories',
    suffix: 'kcal',
    initial: log.calories?.toDouble(),
    integer: true,
    max: 20000,
  );
  if (v == null) return;
  await state.saveDayLog(
    log.copyWith(
      calories: v.isNaN ? null : v.round(),
      nutritionFromHealth: false,
    ),
  );
}

Future<void> editProtein(
  BuildContext context,
  AppState state,
  DateTime day,
) async {
  final log = state.dayLog(day);
  final v = await showNumberDialog(
    context,
    title: 'Protein',
    suffix: 'g',
    initial: log.proteinG,
    max: 1000,
  );
  if (v == null) return;
  await state.saveDayLog(
    log.copyWith(proteinG: v.isNaN ? null : v, nutritionFromHealth: false),
  );
}

Future<void> editNotes(
  BuildContext context,
  AppState state,
  DateTime day,
) async {
  final log = state.dayLog(day);
  final v = await showTextDialog(
    context,
    title: 'Notes · ${DateFormat('d MMM').format(day)}',
    initial: log.notes,
    hint: 'How are you feeling?',
  );
  if (v == null) return;
  await state.saveDayLog(log.copyWith(notes: v.isEmpty ? null : v));
}

Future<void> editSideEffects(
  BuildContext context,
  AppState state,
  DateTime day,
) async {
  final log = state.dayLog(day);
  final result = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SideEffectsSheet(initial: log.sideEffects),
  );
  if (result == null) return;
  await state.saveDayLog(log.copyWith(sideEffects: result));
}

class _SideEffectsSheet extends StatefulWidget {
  final List<String> initial;
  const _SideEffectsSheet({required this.initial});
  @override
  State<_SideEffectsSheet> createState() => _SideEffectsSheetState();
}

class _SideEffectsSheetState extends State<_SideEffectsSheet> {
  late final List<String> _selected = [...widget.initial];
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _addCustom() {
    final s = _custom.text.trim();
    if (s.isEmpty) return;
    setState(() {
      if (!_selected.contains(s)) _selected.add(s);
      _custom.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = {...commonSideEffects, ..._selected}.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Side effects',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                FilterChip(
                  label: Text(o),
                  selected: _selected.contains(o),
                  selectedColor: AppColors.accent.withValues(alpha: 0.3),
                  onSelected: (v) => setState(() {
                    v ? _selected.add(o) : _selected.remove(o);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add another…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addCustom,
              ),
            ),
            onSubmitted: (_) => _addCustom(),
          ),
        ],
      ),
    );
  }
}
