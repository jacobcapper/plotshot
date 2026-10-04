import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'data/database.dart';
import 'data/settings.dart';
import 'screens/home_shell.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final notifications = LocalNotificationService();
  try {
    await notifications.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }
  final state = AppState(
    await AppDatabase.open(),
    await Settings.load(),
    notifications: notifications,
    health: HealthConnectService(),
  );
  await state.load();
  runApp(PlotShotApp(state: state));
}

class PlotShotApp extends StatelessWidget {
  final AppState state;
  const PlotShotApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'PlotShot',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
