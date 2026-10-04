import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final next = state.nextJab();
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
            next.due == null
                ? 'Log a jab and reminders will follow your schedule '
                      '(every ${s.daysBetweenJabs} days).'
                : 'Your next jab is ${next.label.toLowerCase()}. If you miss '
                      'it, you\'ll be reminded again daily for up to '
                      '${AppState.missedJabFollowUps} days.',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
