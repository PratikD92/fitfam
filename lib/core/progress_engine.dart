import '../models/activity_plan.dart';
import '../models/progress_data.dart';
import 'config.dart';
import 'date_utils.dart';

enum GoalStatus { noEatingPlan, noDeficit, achieved, active }

class ProgressSummary {
  final GoalStatus status;
  final double fraction; // 0..1
  final int missedDays;
  final DateTime? goalDate;
  const ProgressSummary({
    required this.status,
    required this.fraction,
    required this.missedDays,
    this.goalDate,
  });
}

class DayInfo {
  final DateTime date;
  final List<ActivityDef> planned;
  final bool done, rest, isFuture, isToday, editable, missed;
  const DayInfo({
    required this.date,
    required this.planned,
    required this.done,
    required this.rest,
    required this.isFuture,
    required this.isToday,
    required this.editable,
    required this.missed,
  });
  bool get hasPlan => planned.isNotEmpty;
}

/// Pure logic for the calendar, streaks, progress and goal date.
///
/// A day is "satisfied" if it has no planned exercise, is marked Rest, or is
/// crossed. Satisfied days add that day's deficit to progress. Past planned
/// days that are neither crossed nor Rest are "missed" and push the goal
/// date back. Today is never missed, and a natural rest day today counts
/// only once the day is over.
class ProgressEngine {
  ProgressEngine({
    required this.history,
    required this.log,
    required this.snapshots,
    required this.goal,
    required this.today,
    required this.liveDeficit,
    required this.hasEatingPlan,
    required this.targetKg,
  });

  final PlanHistory history;
  final ExerciseLog log;
  final Map<String, double> snapshots;
  final GoalState goal;
  final DateTime today; // date only
  final double liveDeficit;
  final bool hasEatingPlan;
  final double targetKg;

  List<ActivityDef> plannedOn(DateTime d) {
    final plan = history.planFor(d);
    if (plan == null) return const [];
    final wd = d.weekday - 1;
    return activityDefs.where((def) => plan.entries[def.id]!.days.contains(wd)).toList();
  }

  DayInfo dayInfo(DateTime d) {
    final k = dateKey(d);
    final planned = plannedOn(d);
    final isFuture = d.isAfter(today);
    final isToday = sameDay(d, today);
    final done = log.done.contains(k);
    final rest = log.rest.contains(k);
    final goalStart = parseKey(goal.goalStart);
    final tracking = parseKey(goal.trackingStart);
    return DayInfo(
      date: d,
      planned: planned,
      done: done,
      rest: rest,
      isFuture: isFuture,
      isToday: isToday,
      editable: !isFuture && !d.isBefore(goalStart),
      missed: !isFuture &&
          !isToday &&
          planned.isNotEmpty &&
          !done &&
          !rest &&
          !d.isBefore(tracking),
    );
  }

  /// Consecutive planned days crossed, counting back from today.
  /// Rest and unplanned days neither break nor add. Today pending is skipped.
  int currentStreak() {
    final start = parseKey(goal.trackingStart);
    var count = 0;
    for (var d = today; !d.isBefore(start); d = addDays(d, -1)) {
      if (plannedOn(d).isEmpty) continue;
      final k = dateKey(d);
      if (log.rest.contains(k)) continue;
      if (log.done.contains(k)) {
        count++;
      } else if (!sameDay(d, today)) {
        break;
      }
    }
    return count;
  }

  int bestStreak() {
    final start = parseKey(goal.trackingStart);
    var run = 0, best = 0;
    for (var d = start; !d.isAfter(today); d = addDays(d, 1)) {
      if (plannedOn(d).isEmpty) continue;
      final k = dateKey(d);
      if (log.rest.contains(k)) continue;
      if (log.done.contains(k)) {
        run++;
        if (run > best) best = run;
      } else if (!sameDay(d, today)) {
        run = 0;
      }
    }
    return best;
  }

  /// (done, planned) planned workout days of [month] up to today.
  (int, int) monthStats(DateTime month) {
    final tracking = parseKey(goal.trackingStart);
    final last = DateTime(month.year, month.month + 1, 0);
    var done = 0, planned = 0;
    for (var d = DateTime(month.year, month.month, 1); !d.isAfter(last); d = addDays(d, 1)) {
      if (d.isAfter(today)) break;
      if (d.isBefore(tracking)) continue;
      final k = dateKey(d);
      if (plannedOn(d).isEmpty || log.rest.contains(k)) continue;
      planned++;
      if (log.done.contains(k)) done++;
    }
    return (done, planned);
  }

  ProgressSummary summary() {
    final needed = (goal.startWeightKg - targetKg) * AppConfig.instance.fatKcalPerKg;
    var done = 0.0;
    var missed = 0;
    var todayCounted = false;

    for (var d = parseKey(goal.goalStart); !d.isAfter(today); d = addDays(d, 1)) {
      final k = dateKey(d);
      final planned = plannedOn(d).isNotEmpty;
      final isToday = sameDay(d, today);
      final isDone = log.done.contains(k);
      final isRest = log.rest.contains(k);
      final counts = isToday ? (planned && (isDone || isRest)) : (!planned || isDone || isRest);
      if (!isToday && planned && !isDone && !isRest) missed++;
      if (counts) {
        done += snapshots[k] ?? liveDeficit;
        if (isToday) todayCounted = true;
      }
    }

    final fraction = needed <= 0 ? 1.0 : (done / needed).clamp(0.0, 1.0).toDouble();

    if (!hasEatingPlan) {
      return ProgressSummary(
          status: GoalStatus.noEatingPlan, fraction: 0, missedDays: missed);
    }
    if (fraction >= 1) {
      return ProgressSummary(
          status: GoalStatus.achieved, fraction: 1, missedDays: missed);
    }
    if (liveDeficit <= 0) {
      return ProgressSummary(
          status: GoalStatus.noDeficit, fraction: fraction, missedDays: missed);
    }
    final daysNeeded = ((needed - done) / liveDeficit).ceil();
    final firstPending = todayCounted ? addDays(today, 1) : today;
    return ProgressSummary(
      status: GoalStatus.active,
      fraction: fraction,
      missedDays: missed,
      goalDate: addDays(firstPending, daysNeeded - 1),
    );
  }
}
