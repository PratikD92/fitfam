import 'activity_plan.dart';

/// The weight goal. Restarts from today when weight or target is edited.
class GoalState {
  final String startDate;
  final double startWeightKg;
  final double targetWeightKg;
  const GoalState(this.startDate, this.startWeightKg, this.targetWeightKg);

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'startWeightKg': startWeightKg,
        'targetWeightKg': targetWeightKg,
      };
  factory GoalState.fromJson(Map<String, dynamic> j) => GoalState(
        j['startDate'] as String,
        (j['startWeightKg'] as num).toDouble(),
        (j['targetWeightKg'] as num).toDouble(),
      );
}

/// Days the user crossed (workout done) and days marked as rest.
class ExerciseLog {
  final Set<String> done;
  final Set<String> rest;
  ExerciseLog({Set<String>? done, Set<String>? rest})
      : done = done ?? <String>{},
        rest = rest ?? <String>{};

  Map<String, dynamic> toJson() =>
      {'done': done.toList()..sort(), 'rest': rest.toList()..sort()};
  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        done: (j['done'] as List).map((e) => e as String).toSet(),
        rest: (j['rest'] as List).map((e) => e as String).toSet(),
      );
}

/// An activity plan that is valid from a date onward.
class PlanVersion {
  final String from;
  final ActivityPlan plan;
  const PlanVersion(this.from, this.plan);

  Map<String, dynamic> toJson() => {'from': from, 'plan': plan.toJson()};
  factory PlanVersion.fromJson(Map<String, dynamic> j) => PlanVersion(
      j['from'] as String, ActivityPlan.fromJson(j['plan'] as Map<String, dynamic>));

  /// The plan that was active on [key]. Null if none yet.
  static ActivityPlan? lookup(List<PlanVersion> list, String key) {
    ActivityPlan? r;
    for (final v in list) {
      if (v.from.compareTo(key) <= 0) {
        r = v.plan;
      } else {
        break;
      }
    }
    return r;
  }
}

/// Daily deficit (kcal) valid from a date onward, so past days keep the
/// deficit they had when they happened.
class DeficitEntry {
  final String from;
  final double deficit;
  const DeficitEntry(this.from, this.deficit);

  Map<String, dynamic> toJson() => {'from': from, 'deficit': deficit};
  factory DeficitEntry.fromJson(Map<String, dynamic> j) =>
      DeficitEntry(j['from'] as String, (j['deficit'] as num).toDouble());

  static double lookup(List<DeficitEntry> list, String key) {
    if (list.isEmpty) return 0;
    var v = list.first.deficit;
    for (final e in list) {
      if (e.from.compareTo(key) <= 0) {
        v = e.deficit;
      } else {
        break;
      }
    }
    return v;
  }
}
