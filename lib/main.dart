import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/config.dart';
import 'core/food_data.dart';
import 'providers/app_state.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await FoodData.load();
  final storage = StorageService();
  await storage.init();
  final state = AppState(storage)..load();
  runApp(ChangeNotifierProvider.value(value: state, child: const FitFamApp()));
}
