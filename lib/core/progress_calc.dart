import 'dart:math' as math;
import '../models/progress.dart';
import 'config.dart';
import 'date_utils.dart';

class ProgressSummary {
  final double totalKcal; // (start kg - target kg) x 7700
  final double progressKcal;
  final int missedCount;
  final int currentStreak;
  final int recordStreak;
  final DateTime? goalDate;
  final bool reached;
  const ProgressSummary({
    required this.totalKcal,
    required this.progressKcal,
    required this.missedCount,
    required this.currentStreak,
    required this.recordStreak,
    required this.goalDate,
    required this.reached,
  });

  double get fraction =>
      totalKcal <= 0 ? 0 : (progressKcal / totalKcal).clamp(0.0, 1.0);
}

/// Rules:
/// - A day counts (adds its deficit) if: a planned workout was crossed, the
///   day was marked Rest, or no workout was planned that day.
/// - A past planned day that is neither crossed nor Rest is MISSED:
///   it adds nothing, breaks the streak and pushes the goal date by 1 day.
/// - Rest days and unplanned days never break (or add to) the streak.
/// - Today is never missed until the day is over.
class ProgressCalc {
  static ProgressSummary compute({
    required GoalState goal,
    required ExerciseLog log,
    required List<PlanVersion> plans,
    required List<DeficitEntry> deficits,
    required double currentDeficit,
    required DateTime now,
  }) {
    final start = parseKey(goal.startDate);
    final today = dayOnly(now);
    var progress = 0.0, missedKcal = 0.0;
    var missed = 0, streak = 0, record = 0;

    for (var d = start; !d.isAfter(today); d = addDays(d, 1)) {
      final key = dateKey(d);
      final plan = PlanVersion.lookup(plans, key);
      final planned = plan != null && plan.defsOn(d.weekday - 1).isNotEmpty;
      final deficit = math.max(0.0, DeficitEntry.lookup(deficits, key));

      if (!planned) {
        progress += deficit; // nothing planned: counts automatically
      } else if (log.done.contains(key)) {
        progress += deficit;
        streak++;
        record = math.max(record, streak);
      } else if (log.rest.contains(key)) {
        progress += deficit; // rest: counts, streak untouched
      } else if (d == today) {
        // still pending
      } else {
        missed++;
        missedKcal += deficit;
        streak = 0;
      }
    }

    final total =
        (goal.startWeightKg - goal.targetWeightKg) * AppConfig.instance.fatKcalPerKg;
    final reached = total > 0 && progress >= total;

    DateTime? goalDate;
    if (!reached && currentDeficit > 0) {
      final remainingIfNoMiss = math.max(0.0, total - progress - missedKcal);
      final baseDays = (remainingIfNoMiss / currentDeficit).ceil();
      goalDate = addDays(today, baseDays + missed);
    }

    return ProgressSummary(
      totalKcal: total,
      progressKcal: progress,
      missedCount: missed,
      currentStreak: streak,
      recordStreak: record,
      goalDate: goalDate,
      reached: reached,
    );
  }
}
