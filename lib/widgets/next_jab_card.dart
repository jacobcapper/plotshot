import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/schedule.dart';
import '../logic/units.dart';
import '../screens/jab_editor_screen.dart';
import '../theme.dart';
import 'common.dart';
import 'inputs.dart';

class NextJabCard extends StatelessWidget {
  const NextJabCard({super.key});

  Future<void> _changeDose(BuildContext context, AppState state) async {
    final med = state.nextMedication;
    if (med == null) return;
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
                trailing: d == state.nextDose
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
                  max: 100,
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
    if (picked != null) await state.setNextDose(med.id!, picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final info = state.nextJab();
    final med = state.nextMedication;
    final dose = state.nextDose;
    final site = state.nextSiteSuggestion;
    final statusColor = switch (info.state) {
      DueState.overdue => AppColors.danger,
      DueState.dueToday => AppColors.warning,
      _ => AppColors.muted,
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: info.state == DueState.upcoming
              ? AppColors.outline
              : AppColors.accent.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Jab ${state.jabs.length + 1}',
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
          if (info.due != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('EEE d MMM').format(info.due!),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          if (med == null)
            const Text('Add a medication in Settings to get started.')
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dose != null) DoseChip(dose),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Change next dose',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  onPressed: () => _changeDose(context, state),
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
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => JabEditorScreen.open(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Jab'),
            ),
          ),
        ],
      ),
    );
  }
}
