import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../services/health_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  HealthAvailability? _availability;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final a = await context.read<AppState>().health.availability();
      if (mounted) setState(() => _availability = a);
    } catch (_) {
      if (mounted) {
        setState(() => _availability = HealthAvailability.unsupported);
      }
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showSnack(context, 'Health Connect error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable(AppState state) => _run(() async {
    final granted = await state.health.requestAccess();
    if (!granted) {
      if (mounted) {
        showSnack(
          context,
          'Permission not granted. You can allow it in Health Connect.',
        );
      }
      return;
    }
    await state.updateSettings((s) {
      s.healthConnectEnabled = true;
      s.lastHealthSync = null; // full back-fill on first sync
    });
    final n = await state.syncHealth();
    if (mounted) showSnack(context, 'Synced $n day${n == 1 ? '' : 's'}');
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'PlotShot can read your weight, calories and protein from Health '
            'Connect, so readings from smart scales and food apps show up '
            'automatically. Anything you enter by hand in PlotShot is never '
            'overwritten.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (_availability == null)
            const Center(child: CircularProgressIndicator())
          else if (_availability == HealthAvailability.unsupported)
            const EmptyHint(
              icon: Icons.heart_broken_outlined,
              text: 'Health Connect isn\'t available on this device.',
            )
          else if (_availability == HealthAvailability.needsInstallOrUpdate)
            EmptyHint(
              icon: Icons.system_update,
              text: 'Health Connect needs to be installed or updated.',
              action: FilledButton(
                onPressed: () async {
                  await state.health.installHealthConnect();
                  await _check();
                },
                child: const Text('Get Health Connect'),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sync from Health Connect'),
                    subtitle: const Text('Weight, calories and protein'),
                    value: s.healthConnectEnabled,
                    onChanged: _busy
                        ? null
                        : (v) => v
                              ? _enable(state)
                              : state.updateSettings(
                                  (x) => x.healthConnectEnabled = false,
                                ),
                  ),
                  if (s.healthConnectEnabled) ...[
                    const Divider(),
                    ListTile(
                      title: const Text('Sync now'),
                      subtitle: Text(
                        s.lastHealthSync == null
                            ? 'Never synced'
                            : 'Last synced ${DateFormat('d MMM, HH:mm').format(s.lastHealthSync!)}',
                      ),
                      trailing: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              final n = await state.syncHealth();
                              if (!context.mounted) return;
                              showSnack(
                                context,
                                'Synced $n day${n == 1 ? '' : 's'}',
                              );
                            }),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
