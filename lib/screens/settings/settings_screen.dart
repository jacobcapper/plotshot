import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/units.dart';
import '../../theme.dart';
import '../../widgets/inputs.dart';
import 'data_screen.dart';
import 'health_screen.dart';
import 'medications_screen.dart';
import 'notifications_screen.dart';
import 'sites_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Measurement Units'),
                subtitle: Text(
                  '${weightUnitLabel(s.weightUnit)} · ${s.heightUnit == HeightUnit.cm ? 'cm' : 'ft/in'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickUnits(context, state),
              ),
              ListTile(
                leading: const Icon(Icons.height),
                title: const Text('Height'),
                subtitle: Text(
                  s.heightCm == null
                      ? 'Not set (needed for BMI)'
                      : formatHeight(s.heightCm!, s.heightUnit),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final cm = await showHeightDialog(
                    context,
                    unit: s.heightUnit,
                    initialCm: s.heightCm,
                  );
                  if (cm != null) {
                    await state.updateSettings((x) => x.heightCm = cm);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Goal Weight'),
                subtitle: Text(
                  s.goalKg == null
                      ? 'Not set'
                      : formatWeight(s.goalKg!, s.weightUnit),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final kg = await showWeightDialog(
                    context,
                    unit: s.weightUnit,
                    initialKg: s.goalKg,
                    title: 'Goal weight',
                    allowRemove: s.goalKg != null,
                  );
                  if (kg == null) return;
                  await state.updateSettings(
                    (x) => x.goalKg = kg < 0 ? null : kg,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Days Between Jabs'),
                subtitle: Text('Every ${s.daysBetweenJabs} days'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final v = await showNumberDialog(
                    context,
                    title: 'Days between jabs',
                    suffix: 'days',
                    initial: s.daysBetweenJabs.toDouble(),
                    integer: true,
                    min: 1,
                    max: 60,
                  );
                  if (v != null && !v.isNaN) {
                    await state.updateSettings(
                      (x) => x.daysBetweenJabs = v.round(),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.vaccines_outlined),
                title: const Text('Injection Sites'),
                subtitle: Text('${s.rotation.length} in rotation'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const SitesScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: const Text('Medications'),
                subtitle: const Text('Doses, half-life and time to peak'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const MedicationsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                subtitle: Text(
                  s.remindersEnabled
                      ? 'Jab day reminder at ${s.reminderTime.format(context)}'
                      : 'Off',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const NotificationsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Health Connect'),
                subtitle: Text(s.healthConnectEnabled ? 'Syncing' : 'Off'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const HealthScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Manage My Data'),
                subtitle: const Text('Export and import a backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(context, const DataScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About PlotShot'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'PlotShot',
                  applicationVersion: '1.0.0',
                  children: const [
                    Text(
                      'A private GLP-1 jab tracker. Your data stays on this '
                      'device.\n\nEstimated medication levels come from a '
                      'simple pharmacokinetic model and are for interest only. '
                      'They are not medical advice. Talk to your prescriber '
                      'about your dosing.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickUnits(BuildContext context, AppState state) async {
    await showModalBottomSheet(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          final s = state.settings;
          Future<void> update(void Function() f) async {
            await state.updateSettings((_) => f());
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weight',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<WeightUnit>(
                    segments: const [
                      ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                      ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                      ButtonSegment(
                        value: WeightUnit.st,
                        label: Text('st & lb'),
                      ),
                    ],
                    selected: {s.weightUnit},
                    onSelectionChanged: (v) =>
                        update(() => s.weightUnit = v.first),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Height',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<HeightUnit>(
                    segments: const [
                      ButtonSegment(value: HeightUnit.cm, label: Text('cm')),
                      ButtonSegment(
                        value: HeightUnit.ftIn,
                        label: Text('ft & in'),
                      ),
                    ],
                    selected: {s.heightUnit},
                    onSelectionChanged: (v) =>
                        update(() => s.heightUnit = v.first),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 56),
          children[i],
        ],
      ],
    ),
  );
}
