import 'dart:convert';
import 'package:flutter/services.dart';

class ActivityLevel {
  final String id;
  final String name;
  final String description;
  final double factor;
  const ActivityLevel(this.id, this.name, this.description, this.factor);
}

class InfoText {
  final String title;
  final String meaning;
  final String formula;
  const InfoText(this.title, this.meaning, this.formula);
}

/// Loads assets/data/config.json. Edit that file to change constants,
/// activity levels, METs or info-popup text. No code change needed.
class AppConfig {
  AppConfig._(this._j);
  final Map<String, dynamic> _j;
  static late AppConfig instance;

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/data/config.json');
    instance = AppConfig._(jsonDecode(raw) as Map<String, dynamic>);
  }

  double get fatKcalPerKg => (_j['fatKcalPerKg'] as num).toDouble();
  double get cmPerFoot => (_j['cmPerFoot'] as num).toDouble();
  double get cmPerInch => (_j['cmPerInch'] as num).toDouble();
  double get mlPerCup => (_j['mlPerCup'] as num).toDouble();
  int get waterResetHour => _j['waterResetHour'] as int;
  int get sleepAutoOffHours => _j['sleepAutoOffHours'] as int;
  double get kcalPerStep => (_j['kcalPerStep'] as num).toDouble();
  int get strengthMinutes => _j['strengthMinutes'] as int;
  double get proteinPerKg => (_j['proteinPerKg'] as num).toDouble();
  List<String> get unitGuide =>
      (_j['unitGuide'] as List).map((e) => e as String).toList();
  int get reminderLeadMinutes => _j['reminderLeadMinutes'] as int;
  List<int> get sessionMinuteOptions =>
      (_j['sessionMinuteOptions'] as List).map((e) => e as int).toList();

  Map<String, double> get mets => (_j['mets'] as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, (v as num).toDouble()));

  List<ActivityLevel> get activityLevels => (_j['activityLevels'] as List)
      .map((e) => ActivityLevel(e['id'] as String, e['name'] as String,
          e['description'] as String, (e['factor'] as num).toDouble()))
      .toList();

  ActivityLevel levelById(String id) => activityLevels
      .firstWhere((l) => l.id == id, orElse: () => activityLevels.first);

  InfoText info(String key) {
    final m = (_j['info'] as Map<String, dynamic>)[key] as Map<String, dynamic>;
    return InfoText(
        m['title'] as String, m['meaning'] as String, m['formula'] as String);
  }
}
