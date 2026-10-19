import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/registration/registration_screen.dart';

class FitFamApp extends StatelessWidget {
  const FitFamApp({super.key});

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
