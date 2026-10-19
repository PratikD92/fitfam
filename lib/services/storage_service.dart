import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageKeys {
  static const profile = 'profile';
  static const activityPlan = 'activityPlan'; // legacy, migrated to activityHistory
  static const activityHistory = 'activityHistory';
  static const deficits = 'deficits';
  static const eatingPlan = 'eatingPlan';
  static const timetable = 'timetable';
  static const sleep = 'sleep';
  static const water = 'water';
  static const exerciseLog = 'exerciseLog';
  static const goal = 'goal';
  static const planHistory = 'planHistory';
  static const deficitSnapshots = 'deficitSnapshots';
}

/// Everything is stored as JSON strings in shared_preferences.
class StorageService {
  late final SharedPreferences _p;

  Future<void> init() async => _p = await SharedPreferences.getInstance();

  Map<String, dynamic>? readMap(String key) {
    final s = _p.getString(key);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      _p.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _p.remove(key);
}
