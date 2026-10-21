import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/logs.dart';
import 'storage_service.dart';

enum SleepAction { start, wake }

/// Records sleep start / wake straight into storage. Used by the notification
/// "Yes" buttons, which run in a background isolate (no AppState there).
class SleepRecorder {
  static Future<void> recordFromPrefs(SleepAction action, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(StorageKeys.sleep);
    final data = raw == null
        ? const SleepData()
        : SleepData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final next = action == SleepAction.start ? data.startedAt(now) : data.wokeAt(now);
    await prefs.setString(StorageKeys.sleep, jsonEncode(next.trimmed().toJson()));
  }
}
