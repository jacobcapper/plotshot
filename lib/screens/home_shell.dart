import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import 'calendar_screen.dart';
import 'jabs_screen.dart';
import 'results_screen.dart';
import 'settings/settings_screen.dart';
import 'summary_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Lets screens switch tabs (e.g. Summary's "See all").
  static void goToTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?.select(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  void select(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _autoSync();
  }

  /// Pulls from Health Connect on open, at most every 30 minutes.
  Future<void> _autoSync() async {
    final state = context.read<AppState>();
    final s = state.settings;
    if (!s.healthConnectEnabled) return;
    final last = s.lastHealthSync;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 30)) {
      return;
    }
    try {
      await state.syncHealth();
    } catch (e) {
      debugPrint('Health sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          SummaryScreen(),
          JabsScreen(),
          ResultsScreen(),
          CalendarScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.vaccines_outlined),
            selectedIcon: Icon(Icons.vaccines),
            label: 'Jabs',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Results',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
