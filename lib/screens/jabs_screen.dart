import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/jab.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/next_jab_card.dart';
import 'jab_editor_screen.dart';

class JabsScreen extends StatelessWidget {
  const JabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final jabs = state.jabs;
    // Newest first, grouped by month.
    final items = <Widget>[];
    String? month;
    for (var i = jabs.length - 1; i >= 0; i--) {
      final j = jabs[i];
      final m = DateFormat('MMMM yyyy').format(j.takenAt).toUpperCase();
      if (m != month) {
        month = m;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              m,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }
      items.add(_JabTile(jab: j, number: i + 1));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jabs'),
        actions: [
          TextButton.icon(
            onPressed: () => JabEditorScreen.open(context),
            icon: const Icon(Icons.add),
            label: const Text('Add jab'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader('Next Jab'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: NextJabCard(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader('History'),
          ),
          if (jabs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: EmptyHint(
                icon: Icons.vaccines_outlined,
                text: 'No jabs logged yet.',
              ),
            ),
          ...items,
        ],
      ),
    );
  }
}

class _JabTile extends StatelessWidget {
  final Jab jab;
  final int number;
  const _JabTile({required this.jab, required this.number});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final med = state.medication(jab.medicationId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => JabEditorScreen.open(context, jab: jab),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Jab $number',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat("EEE d MMM yy 'at' HH:mm")
                            .format(jab.takenAt),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.muted,
                        size: 20,
                      ),
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Delete jab $number?',
                          'This can\'t be undone.',
                        )) {
                          await state.deleteJab(jab);
                        }
                      },
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    Text(
                      med?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DoseChip(jab.doseMg),
                  ],
                ),
                if (jab.site != null || jab.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (jab.site != null) jab.site!,
                        if (jab.notes != null) jab.notes!,
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
