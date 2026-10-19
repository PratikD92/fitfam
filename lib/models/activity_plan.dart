import 'package:flutter/material.dart';
import '../core/calculators.dart';
import '../core/config.dart';

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayFull = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

/// steps: user enters a step count. fixed: fixed duration (strength 45m).
/// timed: user picks 15/30/45/60 minutes.
enum ActivityKind { steps, fixed, timed }

class ActivityDef {
  final String id;
  final String label;
  final IconData icon;
  final ActivityKind kind;
  final String metKey; // key in config.json "mets" (unused for steps)
  final Color color; // colour code used on the Progress calendar
  const ActivityDef(this.id, this.label, this.icon, this.kind, this.metKey, this.color);
}

const activityDefs = <ActivityDef>[
  ActivityDef('steps', 'Daily steps', Icons.directions_walk, ActivityKind.steps, 'walking', Color(0xFF43A047)),
  ActivityDef('strength', 'Strength training', Icons.fitness_center, ActivityKind.fixed, 'strength', Color(0xFF8E24AA)),
  ActivityDef('cardio', 'Cardio', Icons.directions_run, ActivityKind.timed, 'cardio', Color(0xFFFB8C00)),
  ActivityDef('cycling', 'Cycle', Icons.directions_bike, ActivityKind.timed, 'cycling', Color(0xFF1E88E5)),
  ActivityDef('elliptical', 'Elliptical', Icons.nordic_walking, ActivityKind.timed, 'elliptical', Color(0xFF00ACC1)),
  ActivityDef('yoga', 'Yoga', Icons.self_improvement, ActivityKind.timed, 'yoga', Color(0xFFEC407A)),
];

/// "Mon, Wed, Fri", "All days", or "No days selected".
String daysLabel(Set<int> days) {
  if (days.isEmpty) return 'No days selected';
  if (days.length == 7) return 'All days';
  final sorted = days.toList()..sort();
  return sorted.map((i) => weekdayShort[i]).join(', ');
}

class ActivityEntry {
  int? value; // steps count, or minutes for timed activities
  Set<int> days; // 0 = Mon ... 6 = Sun
  ActivityEntry({this.value, Set<int>? days}) : days = days ?? <int>{};

  ActivityEntry copy() => ActivityEntry(value: value, days: {...days});

  Map<String, dynamic> toJson() =>
      {'value': value, 'days': (days.toList()..sort())};

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        value: j['value'] as int?,
        days: (j['days'] as List).map((e) => e as int).toSet(),
      );
}

class ActivityPlan {
  final Map<String, ActivityEntry> entries;
  ActivityPlan(this.entries);

  factory ActivityPlan.empty() =>
      ActivityPlan({for (final d in activityDefs) d.id: ActivityEntry()});

  ActivityPlan copy() =>
      ActivityPlan({for (final e in entries.entries) e.key: e.value.copy()});

  Map<String, dynamic> toJson() =>
      {for (final e in entries.entries) e.key: e.value.toJson()};

  factory ActivityPlan.fromJson(Map<String, dynamic> j) {
    final plan = ActivityPlan.empty();
    for (final d in activityDefs) {
      final m = j[d.id];
      if (m != null) plan.entries[d.id] = ActivityEntry.fromJson(m as Map<String, dynamic>);
    }
    return plan;
  }

  /// Activities planned on a weekday (0 = Mon ... 6 = Sun).
  List<ActivityDef> defsOn(int weekdayIdx) => [
        for (final d in activityDefs)
          if (entries[d.id]!.days.contains(weekdayIdx)) d
      ];

  /// kcal for ONE session. Null until the needed value is filled in.
  double? sessionKcal(ActivityDef d, double weightKg) {
    final cfg = AppConfig.instance;
    final e = entries[d.id]!;
    switch (d.kind) {
      case ActivityKind.steps:
        final s = e.value;
        if (s == null || s <= 0) return null;
        return s * cfg.kcalPerStep;
      case ActivityKind.fixed:
        return Calculators.sessionKcal(
            met: cfg.mets[d.metKey]!,
            weightKg: weightKg,
            minutes: cfg.strengthMinutes.toDouble());
      case ActivityKind.timed:
        final m = e.value;
        if (m == null || m <= 0) return null;
        return Calculators.sessionKcal(
            met: cfg.mets[d.metKey]!, weightKg: weightKg, minutes: m.toDouble());
    }
  }

  /// Total kcal planned for each weekday (index 0 = Mon ... 6 = Sun).
  List<double> kcalPerWeekday(double weightKg) {
    return List.generate(7, (i) {
      var sum = 0.0;
      for (final d in activityDefs) {
        if (entries[d.id]!.days.contains(i)) {
          sum += sessionKcal(d, weightKg) ?? 0;
        }
      }
      return sum;
    });
  }

  double weeklyTotal(double weightKg) =>
      kcalPerWeekday(weightKg).fold(0.0, (a, b) => a + b);

  /// Average daily burn = weekly total / 7.
  double dailyAvg(double weightKg) => weeklyTotal(weightKg) / 7;
}
