import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/config.dart';
import 'core/food_data.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await FoodData.load();
  final storage = StorageService();
  await storage.init();
  final state = AppState(storage)..load();
  try {
    await NotificationService.instance.init();
    await state.rescheduleReminders(); // keeps daily reminders fresh on every launch
  } catch (e) {
    debugPrint('Notification setup failed: $e');
  }
  runApp(ChangeNotifierProvider.value(value: state, child: const FitFamApp()));
}
