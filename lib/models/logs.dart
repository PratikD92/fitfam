/// Sleep and water data models. UI/logic for these arrives with the Dashboard.

class SleepLog {
  final DateTime start;
  final DateTime end;
  final double hours;
  const SleepLog(this.start, this.end, this.hours);

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'hours': hours,
      };
  factory SleepLog.fromJson(Map<String, dynamic> j) => SleepLog(
        DateTime.parse(j['start'] as String),
        DateTime.parse(j['end'] as String),
        (j['hours'] as num).toDouble(),
      );
}

class SleepData {
  /// Non-null while the sleep toggle is ON. Auto-closed after 7 h (config).
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
}

class WaterData {
  /// Bottle refills per "water day". A water day runs 6:00 AM to 6:00 AM,
  /// so the key is the date of (now − 6h), e.g. "2026-10-19".
  final Map<String, int> refillsByDay;
  final int bottleMl;
  const WaterData({this.refillsByDay = const {}, this.bottleMl = 1000});

  static String dayKey(DateTime t, int resetHour) {
    final d = t.subtract(Duration(hours: resetHour));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() =>
      {'refillsByDay': refillsByDay, 'bottleMl': bottleMl};
  factory WaterData.fromJson(Map<String, dynamic> j) => WaterData(
        refillsByDay: (j['refillsByDay'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        bottleMl: j['bottleMl'] as int,
      );
}
