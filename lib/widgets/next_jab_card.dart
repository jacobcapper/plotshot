import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/schedule.dart';
import '../logic/units.dart';
import '../models/medication.dart';
import '../screens/jab_editor_screen.dart';
import '../theme.dart';
import 'common.dart';
import 'inputs.dart';

/// One card per scheduled medication, or a "first jab" card when nothing is
/// scheduled yet.
class NextJabCards extends StatelessWidget {
  const NextJabCards({super.key});

  @override
  Widget build(BuildContext context) {
    final meds = context.watch<AppState>().scheduledMedications;
    if (meds.isEmpty) return const NextJabCard(medication: null);
    return Column(
      children: [
        for (final (i, m) in meds.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          NextJabCard(medication: m),
        ],
      ],
    );
  }
}

class NextJabCard extends StatelessWidget {
  final Medication? medication;
  const NextJabCard({super.key, required this.medication});

  Future<void> _changeDose(
    BuildContext context,
    AppState state,
    Medication med,
  ) async {
    final current = state.nextDose(med);
    final picked = await showModalBottomSheet<double>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Next ${med.name} dose',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final d in med.doses)
              ListTile(
                title: Text('${formatDose(d)} mg'),
                trailing: d == current
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(c, d),
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Custom dose…'),
              onTap: () async {
                final v = await showNumberDialog(
                  c,
                  title: 'Dose',
                  suffix: 'mg',
                  min: 0.01,
                  max: 10000,
                );
                if (c.mounted) {
                  Navigator.pop(c, v == null || v.isNaN ? null : v);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) await state.setNextDose(med, picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final med = medication;
    if (med == null) {
      return _frame(
        highlighted: true,
        children: [
          const Text(
            'Log your first jab',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Each medication keeps its own schedule. Set the days between '
            'jabs for each one in Settings → Medications.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          _addButton(context, null),
        ],
      );
    }

    final info = state.nextJab(med);
    final dose = state.nextDose(med);
    final site = state.nextSiteFor(med);
    final statusColor = switch (info.state) {
      DueState.overdue => AppColors.danger,
      DueState.dueToday => AppColors.warning,
      _ => AppColors.muted,
    };
    return _frame(
      highlighted: info.state != DueState.upcoming,
      children: [
        Row(
          children: [
            Text(
              'Jab ${state.jabsFor(med.id!).length + 1}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info.label,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            [
              if (info.due != null) DateFormat('EEE d MMM').format(info.due!),
              'every ${formatDays(med.daysBetweenJabs)} days',
            ].join(' · '),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(
              med.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dose != null) DoseChip(dose),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Change next ${med.name} dose',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  onPressed: () => _changeDose(context, state, med),
                ),
              ],
            ),
          ],
        ),
        if (site != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              site,
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ),
        const SizedBox(height: 12),
        _addButton(context, med),
      ],
    );
  }

  Widget _addButton(BuildContext context, Medication? med) => Align(
    alignment: Alignment.centerRight,
    child: FilledButton.icon(
      onPressed: () => JabEditorScreen.open(context, medication: med),
      icon: const Icon(Icons.add),
      label: const Text('Add Jab'),
    ),
  );

  Widget _frame({required bool highlighted, required List<Widget> children}) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.outline,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}
