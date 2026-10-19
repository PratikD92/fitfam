import '../core/date_utils.dart';
import 'activity_plan.dart';

/// When tracking began, when the current goal began, and the weight then.
/// goalStart + startWeightKg reset when the user changes their weight.
class GoalState {
  final String trackingStart; // never changes
  final String goalStart;
  final double startWeightKg;
  const GoalState({
    required this.trackingStart,
    required this.goalStart,
    required this.startWeightKg,
  });

  Map<String, dynamic> toJson() => {
        'trackingStart': trackingStart,
        'goalStart': goalStart,
        'startWeightKg': startWeightKg,
      };
  factory GoalState.fromJson(Map<String, dynamic> j) => GoalState(
        trackingStart: j['trackingStart'] as String,
        goalStart: j['goalStart'] as String,
        startWeightKg: (j['startWeightKg'] as num).toDouble(),
      );
}

/// Days the user crossed (done) and days marked as rest, as "yyyy-MM-dd".
class ExerciseLog {
  final Set<String> done;
  final Set<String> rest;
  ExerciseLog({Set<String>? done, Set<String>? rest})
      : done = done ?? <String>{},
        rest = rest ?? <String>{};

  Map<String, dynamic> toJson() =>
      {'done': (done.toList()..sort()), 'rest': (rest.toList()..sort())};
  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        done: (j['done'] as List).map((e) => e as String).toSet(),
        rest: (j['rest'] as List).map((e) => e as String).toSet(),
      );
}

class PlanVersion {
  final String from; // first day this plan applies
  final ActivityPlan plan;
  PlanVersion(this.from, this.plan);

  Map<String, dynamic> toJson() => {'from': from, 'plan': plan.toJson()};
  factory PlanVersion.fromJson(Map<String, dynamic> j) => PlanVersion(
      j['from'] as String, ActivityPlan.fromJson(j['plan'] as Map<String, dynamic>));
}

/// Past days keep the plan that was active on them.
class PlanHistory {
  final List<PlanVersion> versions; // ascending by [from]
  PlanHistory(this.versions);

  ActivityPlan? planFor(DateTime d) {
    final k = dateKey(d);
    ActivityPlan? result;
    for (final v in versions) {
      if (v.from.compareTo(k) <= 0) result = v.plan;
    }
    return result;
  }

  Map<String, dynamic> toJson() =>
      {'versions': versions.map((v) => v.toJson()).toList()};
  factory PlanHistory.fromJson(Map<String, dynamic> j) => PlanHistory(
      (j['versions'] as List)
          .map((e) => PlanVersion.fromJson(e as Map<String, dynamic>))
          .toList());
}
