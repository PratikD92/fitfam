import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/calculators.dart';
import '../core/config.dart';
import '../core/date_utils.dart';
import '../core/progress_engine.dart';
import '../models/activity_plan.dart';
import '../models/eating_plan.dart';
import '../models/logs.dart';
import '../models/progress_data.dart';
import '../models/timetable.dart';
import '../models/user_profile.dart';
import '../models/weight_log.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);
  final StorageService _storage;

  UserProfile? _profile;
  ActivityPlan _activityPlan = ActivityPlan.empty();
  PlanHistory _history = PlanHistory([]);
  EatingPlan _eatingPlan = EatingPlan.empty();
  Timetable _timetable = Timetable.defaults();
  GoalState? _goal;
  ExerciseLog _log = ExerciseLog();
  Map<String, double> _snapshots = {};
  SleepData _sleep = const SleepData();
  WaterData _water = const WaterData();
  WeightLog _weightLog = WeightLog.empty();

  UserProfile? get profile => _profile;
  bool get hasProfile => _profile != null;
  ActivityPlan get activityPlan => _activityPlan;
  EatingPlan get eatingPlan => _eatingPlan;
  Timetable get timetable => _timetable;
  WeightLog get weightLog => _weightLog;

  // ---- shared calculations (one place; Dashboard and Progress both use these)
  double get bmr => _profile == null
      ? 0
      : Calculators.bmr(
          weightKg: _profile!.weightKg,
          heightCm: _profile!.heightCm,
          age: _profile!.age,
          gender: _profile!.gender);
  double get tdee => _profile == null
      ? 0
      : Calculators.tdee(
          bmr, AppConfig.instance.levelById(_profile!.activityLevelId).factor);
  double get dailyBurn =>
      _profile == null ? 0 : _activityPlan.dailyAvg(_profile!.weightKg);
  /// Activity levels already include exercise, so workouts are added to a
  /// sedentary base (BMR x 1.2) instead of to TDEE. See config.json.
  double get finalTdeeBase => AppConfig.instance.finalTdeeUsesSedentaryBase
      ? bmr * AppConfig.instance.levelById('sedentary').factor
      : tdee;
  String get finalTdeeBaseLabel => AppConfig.instance.finalTdeeUsesSedentaryBase
      ? 'BMR × ${AppConfig.instance.levelById('sedentary').factor}'
      : 'TDEE';
  double get finalTdee => Calculators.finalTdee(finalTdeeBase, dailyBurn);
  double get dailyEating => _eatingPlan.dailyKcal;
  bool get hasEatingPlan => dailyEating > 0;
  double get dailyDeficit => Calculators.deficit(finalTdee, dailyEating);

  // ---- load
  void load() {
    final today = dateOnly(DateTime.now());

    final p = _storage.readMap(StorageKeys.profile);
    if (p != null) _profile = UserProfile.fromJson(p);
    final a = _storage.readMap(StorageKeys.activityPlan);
    if (a != null) _activityPlan = ActivityPlan.fromJson(a);
    final e = _storage.readMap(StorageKeys.eatingPlan);
    if (e != null) _eatingPlan = EatingPlan.fromJson(e);
    final h = _storage.readMap(StorageKeys.planHistory);
    if (h != null) _history = PlanHistory.fromJson(h);
    final tt = _storage.readMap(StorageKeys.timetable);
    if (tt != null) _timetable = Timetable.fromJson(tt);
    final sl = _storage.readMap(StorageKeys.sleep);
    if (sl != null) _sleep = SleepData.fromJson(sl);
    final wt = _storage.readMap(StorageKeys.water);
    if (wt != null) _water = WaterData.fromJson(wt);
    final wl = _storage.readMap(StorageKeys.weightLog);
    if (wl != null) _weightLog = WeightLog.fromJson(wl);
    final g = _storage.readMap(StorageKeys.goal);
    if (g != null) _goal = GoalState.fromJson(g);
    final l = _storage.readMap(StorageKeys.exerciseLog);
    if (l != null) _log = ExerciseLog.fromJson(l);
    final s = _storage.readMap(StorageKeys.deficitSnapshots);
    if (s != null) {
      _snapshots = s.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    // Daily deficit formula changed (no double counting): recalculate past days once.
    final fv = _storage.readMap(StorageKeys.formulaVersion);
    if ((fv?['v'] as int?) != 2) {
      _snapshots = {};
      _storage.writeJson(StorageKeys.deficitSnapshots, {});
      _storage.writeJson(StorageKeys.formulaVersion, {'v': 2});
    }

    // Migrations for data saved before Progress existed.
    if (_profile != null && _goal == null) {
      _goal = GoalState(
          trackingStart: dateKey(today),
          goalStart: dateKey(today),
          startWeightKg: _profile!.weightKg);
      _saveGoal();
    }
    if (_history.versions.isEmpty &&
        _activityPlan.entries.values.any((x) => x.days.isNotEmpty)) {
      _history = PlanHistory(
          [PlanVersion(_goal?.trackingStart ?? dateKey(today), _activityPlan.copy())]);
      _saveHistory();
    }
    ensureSnapshots();

    // Close a sleep toggle that was left on for too long.
    final resolved = _sleep.resolved(DateTime.now());
    if (!identical(resolved, _sleep)) {
      _sleep = resolved;
      _saveSleep();
    }
  }

  // ---- profile
  Future<void> saveProfile(UserProfile p) async {
    final old = _profile;
    await _storage.writeJson(StorageKeys.profile, p.toJson());
    _profile = p;
    final todayKey = dateKey(dateOnly(DateTime.now()));
    if (_goal == null) {
      _goal = GoalState(
          trackingStart: todayKey, goalStart: todayKey, startWeightKg: p.weightKg);
      await _saveGoal();
    } else if (old != null && old.weightKg != p.weightKg) {
      // Weight changed: restart the goal from today.
      _goal = GoalState(
          trackingStart: _goal!.trackingStart,
          goalStart: todayKey,
          startWeightKg: p.weightKg);
      await _saveGoal();
    }
    notifyListeners();
  }

  // ---- activity plan (keeps history so past days keep their old plan)
  Future<void> saveActivityPlan(ActivityPlan plan) async {
    await _storage.writeJson(StorageKeys.activityPlan, plan.toJson());
    _activityPlan = plan;

    final todayKey = dateKey(dateOnly(DateTime.now()));
    final versions = [..._history.versions]..removeWhere((v) => v.from == todayKey);
    final hasDays = plan.entries.values.any((x) => x.days.isNotEmpty);
    final latest = versions.isEmpty ? null : versions.last;
    final changed = latest == null
        ? hasDays
        : jsonEncode(latest.plan.toJson()) != jsonEncode(plan.toJson());
    if (changed) versions.add(PlanVersion(todayKey, plan.copy()));
    versions.sort((a, b) => a.from.compareTo(b.from));
    _history = PlanHistory(versions);
    await _saveHistory();
    notifyListeners();
  }

  // ---- timetable + reminders
  Future<void> saveTimetable(Timetable t) async {
    await _storage.writeJson(StorageKeys.timetable, t.toJson());
    _timetable = t;
    notifyListeners();
    await NotificationService.instance.scheduleAll(t);
    await rescheduleSleepPrompts();
  }

  Future<void> rescheduleReminders() async {
    await NotificationService.instance.scheduleAll(_timetable);
    await rescheduleSleepPrompts();
  }

  // ---- eating plan
  Future<void> saveEatingPlan(EatingPlan plan) async {
    await _storage.writeJson(StorageKeys.eatingPlan, plan.toJson());
    _eatingPlan = plan;
    notifyListeners();
  }

  // ---- sleep
  bool get isSleeping => _sleep.sleepStart != null;
  double? get lastSleepHours => _sleep.logs.isEmpty ? null : _sleep.logs.last.hours;

  Future<void> toggleSleep() async {
    final now = DateTime.now();
    final r = _sleep.resolved(now);
    _sleep = r.sleepStart == null ? r.startedAt(now) : r.wokeAt(now);
    await _saveSleep();
    notifyListeners();
    await rescheduleSleepPrompts();
  }

  Future<void> _saveSleep() =>
      _storage.writeJson(StorageKeys.sleep, _sleep.trimmed().toJson());

  /// Silent prompts use the 3-day average bedtime / wake-up, falling back to
  /// the Time Table until there is data.
  Future<void> rescheduleSleepPrompts() {
    final cfg = AppConfig.instance;
    final avg = _sleep.averageTimes(days: 3);
    int? fromTable(String id) {
      for (final e in _timetable.entries) {
        if (e.id == id) return e.minutesOfDay;
      }
      return null;
    }

    final sleepAt = avg.sleep ?? fromTable('sleep') ?? 23 * 60;
    final wakeAt = avg.wake ?? fromTable('wake') ?? 7 * 60;
    return NotificationService.instance.scheduleSleepPrompts(
      sleepPromptMinutes: sleepAt - cfg.sleepPromptLeadMinutes,
      wakePromptMinutes: wakeAt - cfg.wakePromptLeadMinutes,
    );
  }

  /// Called when the app returns to the foreground: picks up anything the
  /// notification "Yes" buttons recorded while the app was closed.
  Future<void> refreshFromStorage() async {
    await _storage.reload();
    final sl = _storage.readMap(StorageKeys.sleep);
    if (sl != null) _sleep = SleepData.fromJson(sl);
    final resolved = _sleep.resolved(DateTime.now());
    if (!identical(resolved, _sleep)) {
      _sleep = resolved;
      await _saveSleep();
    }
    notifyListeners();
    await rescheduleReminders(); // keeps every daily alarm fresh
  }

  // ---- water
  String get _waterKey =>
      WaterData.dayKey(DateTime.now(), AppConfig.instance.waterResetHour);
  int get waterRefillsToday => _water.refills(_waterKey);
  int get waterBottleMl => _water.bottleMl;
  int get waterGoalMl => _water.goalMl;
  int get waterMlToday => _water.totalMl(_waterKey);

  /// (average ml per day, days of data) over the last 7 water days.
  (int, int) waterWeekAverage() {
    final reset = AppConfig.instance.waterResetHour;
    final now = DateTime.now();
    var sum = 0, days = 0;
    for (var i = 0; i < 7; i++) {
      final key = WaterData.dayKey(now.subtract(Duration(days: i)), reset);
      if (_water.refills(key) > 0) {
        sum += _water.totalMl(key);
        days++;
      }
    }
    return days == 0 ? (0, 0) : (sum ~/ days, days);
  }

  Future<void> addRefill() => _changeRefill(1);
  Future<void> removeRefill() => _changeRefill(-1);

  Future<void> _changeRefill(int delta) async {
    _water = _water.withRefill(_waterKey, delta);
    await _storage.writeJson(StorageKeys.water, _water.toJson());
    notifyListeners();
  }

  Future<void> saveWaterSettings({required int goalMl, required int bottleMl}) async {
    _water = _water.withSettings(_waterKey, goalMl: goalMl, bottleMl: bottleMl);
    await _storage.writeJson(StorageKeys.water, _water.toJson());
    notifyListeners();
  }

  // ---- weight tracking (standalone, affects nothing else)
  Future<void> saveWeightLog(WeightLog log) async {
    await _storage.writeJson(StorageKeys.weightLog, log.toJson());
    _weightLog = log;
    notifyListeners();
  }

  // ---- progress
  ProgressEngine? engine() {
    final p = _profile, g = _goal;
    if (p == null || g == null) return null;
    return ProgressEngine(
      history: _history,
      log: _log,
      snapshots: _snapshots,
      goal: g,
      today: dateOnly(DateTime.now()),
      liveDeficit: dailyDeficit,
      hasEatingPlan: hasEatingPlan,
      targetKg: p.targetWeightKg,
    );
  }

  ProgressSummary? progressSummary() => engine()?.summary();

  /// Past days keep the deficit they had, so editing your eating plan today
  /// does not rewrite history. Today is not snapshotted until tomorrow.
  void ensureSnapshots() {
    final g = _goal;
    if (g == null || _profile == null || !hasEatingPlan) return;
    final today = dateOnly(DateTime.now());
    var changed = false;
    for (var d = parseKey(g.goalStart); d.isBefore(today); d = addDays(d, 1)) {
      final k = dateKey(d);
      if (!_snapshots.containsKey(k)) {
        _snapshots[k] = dailyDeficit;
        changed = true;
      }
    }
    if (changed) _storage.writeJson(StorageKeys.deficitSnapshots, _snapshots);
  }

  /// Cross / uncross a day. Future days are never allowed.
  Future<void> toggleDone(DateTime d) async {
    final day = dateOnly(d);
    if (day.isAfter(dateOnly(DateTime.now()))) return;
    final k = dateKey(day);
    if (!_log.done.remove(k)) {
      _log.done.add(k);
      _log.rest.remove(k);
    }
    await _saveLog();
    notifyListeners();
  }

  Future<void> setRest(DateTime d, bool rest) async {
    final day = dateOnly(d);
    if (day.isAfter(dateOnly(DateTime.now()))) return;
    final k = dateKey(day);
    if (rest) {
      _log.rest.add(k);
      _log.done.remove(k);
    } else {
      _log.rest.remove(k);
    }
    await _saveLog();
    notifyListeners();
  }

  Future<void> _saveGoal() => _storage.writeJson(StorageKeys.goal, _goal!.toJson());
  Future<void> _saveHistory() =>
      _storage.writeJson(StorageKeys.planHistory, _history.toJson());
  Future<void> _saveLog() => _storage.writeJson(StorageKeys.exerciseLog, _log.toJson());
}
