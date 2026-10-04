import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/sites.dart';
import '../../theme.dart';

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rotation = state.settings.rotation;
    final others = allInjectionSites
        .where((s) => !rotation.contains(s))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Injection Sites')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Sites in your rotation are suggested in order for each new jab. '
            'Drag to reorder.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          const Text(
            'ACTIVE ROTATION',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (rotation.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No sites in rotation.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => state.updateSettings((s) {
              final x = s.rotation.removeAt(from);
              s.rotation.insert(to, x);
            }),
            children: [
              for (var i = 0; i < rotation.length; i++)
                Card(
                  key: ValueKey(rotation[i]),
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Switch(
                      value: true,
                      onChanged: (_) => state.updateSettings(
                        (s) => s.rotation.remove(rotation[i]),
                      ),
                    ),
                    title: Text(rotation[i]),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(
                        Icons.drag_handle,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'OTHER SITES',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final site in others)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Switch(
                    value: false,
                    onChanged: (_) =>
                        state.updateSettings((s) => s.rotation.add(site)),
                  ),
                  title: Text(
                    site,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
