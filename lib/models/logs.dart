/// Sleep and water data models.

/// A toggle left ON for longer than this counts as "forgotten".
const kForgottenAfterHours = 12;

/// A forgotten sleep is recorded as this many hours.
const kForgottenRecordHours = 7;

/// "Woke up" tapped with no recorded start: assume this many hours.
const kEstimatedSleepHours = 7;

class SleepLog {
  final DateTime start;
  final DateTime end;
  final double hours;
  final bool estimated; // true when the start was not recorded
  const SleepLog(this.start, this.end, this.hours, {this.estimated = false});

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'hours': hours,
        'estimated': estimated,
      };
  factory SleepLog.fromJson(Map<String, dynamic> j) => SleepLog(
        DateTime.parse(j['start'] as String),
        DateTime.parse(j['end'] as String),
        (j['hours'] as num).toDouble(),
        estimated: (j['estimated'] as bool?) ?? false,
      );
}

/// Pure logic, so the app and the notification "Yes" button share it.
class SleepData {
  /// Non-null while sleeping (toggle ON).
  final DateTime? sleepStart;
  final List<SleepLog> logs;
  const SleepData({this.sleepStart, this.logs = const []});

  Map<String, dynamic> toJson() => {
        'sleepStart': sleepStart?.toIso8601String(),
        'logs': logs.map((e) => e.toJson()).toList(),
      };
  factory SleepData.fromJson(Map<String, dynamic> j) => SleepData(
        sleepStart: j['sleepStart'] == null
            ? null
            : DateTime.parse(j['sleepStart'] as String),
        logs: (j['logs'] as List)
            .map((e) => SleepLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Closes a forgotten sleep (ON for more than [kForgottenAfterHours]) and
  /// records it as [kForgottenRecordHours]. Returns `this` if nothing changed.
  SleepData resolved(DateTime now) {
    final s = sleepStart;
    if (s == null) return this;
    if (now.difference(s) <= const Duration(hours: kForgottenAfterHours)) return this;
    final end = s.add(const Duration(hours: kForgottenRecordHours));
    return SleepData(
      logs: [...logs, SleepLog(s, end, kForgottenRecordHours.toDouble())],
    );
  }

  SleepData startedAt(DateTime now) {
    final d = resolved(now);
    if (d.sleepStart != null) return d; // already sleeping
    return SleepData(sleepStart: now, logs: d.logs);
  }

  SleepData wokeAt(DateTime now) {
    final d = resolved(now);
    if (d.logs.length > logs.length) return d; // a forgotten sleep was just closed
    final s = d.sleepStart;
    if (s == null) {
      // Woke up with no recorded start. Ignore repeat taps, else estimate.
      if (logs.isNotEmpty && now.difference(logs.last.end) < const Duration(hours: 3)) {
        return this;
      }
      final est = now.subtract(const Duration(hours: kEstimatedSleepHours));
      return SleepData(logs: [
        ...d.logs,
        SleepLog(est, now, kEstimatedSleepHours.toDouble(), estimated: true),
      ]);
    }
    final hours = now.difference(s).inMinutes / 60.0;
    return SleepData(logs: [...d.logs, SleepLog(s, now, hours)]);
  }

  SleepData trimmed() => logs.length <= 90
      ? this
      : SleepData(sleepStart: sleepStart, logs: logs.sublist(logs.length - 90));

  /// Average bedtime and wake-up (minutes of day) over the last [days] logs.
  /// Bedtime averaging handles times around midnight. Estimated logs are not
  /// used for bedtime.
  ({int? sleep, int? wake}) averageTimes({int days = 3}) {
    final recent = logs.length <= days ? logs : logs.sublist(logs.length - days);
    final starts = recent
        .where((l) => !l.estimated)
        .map((l) => l.start.hour * 60 + l.start.minute)
        .toList();
    final wakes = recent.map((l) => l.end.hour * 60 + l.end.minute).toList();

    int? sleep;
    if (starts.isNotEmpty) {
      final shifted = starts.map((m) => (m + 720) % 1440).toList();
      final mean = shifted.reduce((a, b) => a + b) / shifted.length;
      sleep = (mean.round() + 720) % 1440;
    }
    int? wake;
    if (wakes.isNotEmpty) {
      wake = (wakes.reduce((a, b) => a + b) / wakes.length).round();
    }
    return (sleep: sleep, wake: wake);
  }
}

class WaterData {
  /// A "water day" runs 6:00 AM to 6:00 AM. Key = date of (now - 6h).
  final Map<String, int> refillsByDay;

  /// Bottle size used for each day, so past days keep their own total.
  final Map<String, int> bottleMlByDay;
  final int bottleMl; // current bottle capacity
  final int goalMl; // daily goal

  const WaterData({
    this.refillsByDay = const {},
    this.bottleMlByDay = const {},
    this.bottleMl = 1000,
    this.goalMl = 3000,
  });

  static String dayKey(DateTime t, int resetHour) {
    final d = t.subtract(Duration(hours: resetHour));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  int refills(String key) => refillsByDay[key] ?? 0;
  int totalMl(String key) => refills(key) * (bottleMlByDay[key] ?? bottleMl);

  WaterData withRefill(String key, int delta) {
    final r = {...refillsByDay};
    final b = {...bottleMlByDay};
    var n = (r[key] ?? 0) + delta;
    if (n < 0) n = 0;
    if (n > 999) n = 999;
    r[key] = n;
    b.putIfAbsent(key, () => bottleMl);
    return WaterData(
        refillsByDay: r, bottleMlByDay: b, bottleMl: bottleMl, goalMl: goalMl);
  }

  /// New settings apply to today's total as well (refills x capacity).
  WaterData withSettings(String todayKey,
      {required int goalMl, required int bottleMl}) {
    final b = {...bottleMlByDay};
    if (refillsByDay.containsKey(todayKey)) b[todayKey] = bottleMl;
    return WaterData(
        refillsByDay: refillsByDay,
        bottleMlByDay: b,
        bottleMl: bottleMl,
        goalMl: goalMl);
  }

  Map<String, dynamic> toJson() => {
        'refillsByDay': refillsByDay,
        'bottleMlByDay': bottleMlByDay,
        'bottleMl': bottleMl,
        'goalMl': goalMl,
      };
  factory WaterData.fromJson(Map<String, dynamic> j) => WaterData(
        refillsByDay: ((j['refillsByDay'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as int)),
        bottleMlByDay: ((j['bottleMlByDay'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as int)),
        bottleMl: (j['bottleMl'] as int?) ?? 1000,
        goalMl: (j['goalMl'] as int?) ?? 3000,
      );
}
