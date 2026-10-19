import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/calculators.dart';
import '../core/config.dart';
import '../core/date_utils.dart';
import '../core/progress_engine.dart';
import '../models/activity_plan.dart';
import '../models/eating_plan.dart';
import '../models/progress_data.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);
  final StorageService _storage;

  UserProfile? _profile;
  ActivityPlan _activityPlan = ActivityPlan.empty();
  PlanHistory _history = PlanHistory([]);
  EatingPlan _eatingPlan = EatingPlan.empty();
  GoalState? _goal;
  ExerciseLog _log = ExerciseLog();
  Map<String, double> _snapshots = {};

  UserProfile? get profile => _profile;
  bool get hasProfile => _profile != null;
  ActivityPlan get activityPlan => _activityPlan;
  EatingPlan get eatingPlan => _eatingPlan;

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
  double get finalTdee => Calculators.finalTdee(tdee, dailyBurn);
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
    final g = _storage.readMap(StorageKeys.goal);
    if (g != null) _goal = GoalState.fromJson(g);
    final l = _storage.readMap(StorageKeys.exerciseLog);
    if (l != null) _log = ExerciseLog.fromJson(l);
    final s = _storage.readMap(StorageKeys.deficitSnapshots);
    if (s != null) {
      _snapshots = s.map((k, v) => MapEntry(k, (v as num).toDouble()));
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

  // ---- eating plan
  Future<void> saveEatingPlan(EatingPlan plan) async {
    await _storage.writeJson(StorageKeys.eatingPlan, plan.toJson());
    _eatingPlan = plan;
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
