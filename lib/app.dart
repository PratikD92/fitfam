import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/registration/registration_screen.dart';

class FitFamApp extends StatefulWidget {
  const FitFamApp({super.key});
  @override
  State<FitFamApp> createState() => _FitFamAppState();
}

class _FitFamAppState extends State<FitFamApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pick up sleep / wake times recorded from notifications while away.
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refreshFromStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFam',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Consumer<AppState>(
        builder: (_, state, __) =>
            state.hasProfile ? const DashboardScreen() : const RegistrationScreen(),
      ),
    );
  }
}
