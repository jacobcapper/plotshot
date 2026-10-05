import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/schedule.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final scheduled = state.scheduledMedications;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Jab day reminder'),
                  subtitle: const Text(
                    'A notification on the day your next jab is due',
                  ),
                  value: s.remindersEnabled,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await state.notifications.requestPermission();
                      if (!ok && context.mounted) {
                        showSnack(
                          context,
                          'Allow notifications for PlotShot in Android settings.',
                        );
                      }
                    }
                    await state.updateSettings((x) => x.remindersEnabled = v);
                  },
                ),
                const Divider(),
                ListTile(
                  enabled: s.remindersEnabled,
                  title: const Text('Reminder time'),
                  trailing: Text(
                    s.reminderTime.format(context),
                    style: const TextStyle(fontSize: 16),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: s.reminderTime,
                    );
                    if (t != null) {
                      await state.updateSettings((x) => x.reminderTime = t);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            scheduled.isEmpty
                ? 'Reminders follow each medication\'s own schedule, set in '
                      'Settings → Medications. Log a jab to start one.'
                : 'Each active medication gets its own reminder on its jab '
                      'day. If you miss one, you\'ll be reminded again daily '
                      'for up to ${AppState.missedJabFollowUps} days.',
            style: const TextStyle(color: AppColors.muted),
          ),
          for (final m in scheduled)
            if (state.nextJab(m).due case final due?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${m.name}: ${state.nextJab(m).label.toLowerCase()} '
                  '(${DateFormat('EEE d MMM').format(due)}), every '
                  '${formatDays(m.daysBetweenJabs)} days',
                ),
              ),
        ],
      ),
    );
  }
}
