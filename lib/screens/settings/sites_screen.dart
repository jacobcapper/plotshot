import 'package:flutter/material.dart';

import '../../logic/sites.dart';
import '../../theme.dart';

/// Edits one medication's injection site rotation. Pops with the new list.
class SitesScreen extends StatefulWidget {
  final String medicationName;
  final List<String> initial;
  const SitesScreen({
    super.key,
    required this.medicationName,
    required this.initial,
  });

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  late final List<String> _rotation = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final others = [...allInjectionSites.where((s) => !_rotation.contains(s))];
    return PopScope<List<String>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _rotation);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.medicationName} Sites')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text(
              'Sites in the rotation are suggested in order for each new jab '
              'of this medication. Drag to reorder.',
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
            if (_rotation.isEmpty)
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
              onReorderItem: (from, to) => setState(() {
                final x = _rotation.removeAt(from);
                _rotation.insert(to, x);
              }),
              children: [
                for (var i = 0; i < _rotation.length; i++)
                  Card(
                    key: ValueKey(_rotation[i]),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: Switch(
                        value: true,
                        onChanged: (_) => setState(() => _rotation.removeAt(i)),
                      ),
                      title: Text(_rotation[i]),
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
                      onChanged: (_) => setState(() => _rotation.add(site)),
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
      ),
    );
  }
}
