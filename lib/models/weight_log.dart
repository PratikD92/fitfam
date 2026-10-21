import '../core/date_utils.dart';

class WeightEntry {
  final String id;
  final DateTime date; // date only
  final double kg;
  const WeightEntry({required this.id, required this.date, required this.kg});

  Map<String, dynamic> toJson() => {'id': id, 'date': dateKey(date), 'kg': kg};
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        id: j['id'] as String,
        date: parseKey(j['date'] as String),
        kg: (j['kg'] as num).toDouble(),
      );
}

class MonthAvg {
  final DateTime month; // first day of month
  final double avg;
  final int count;
  const MonthAvg(this.month, this.avg, this.count);
}

/// Standalone weight history. Does not change the profile weight or any
/// other screen's data.
class WeightLog {
  final List<WeightEntry> entries;
  const WeightLog(this.entries);
  factory WeightLog.empty() => const WeightLog([]);

  Map<String, dynamic> toJson() => {'entries': entries.map((e) => e.toJson()).toList()};
  factory WeightLog.fromJson(Map<String, dynamic> j) => WeightLog((j['entries'] as List)
      .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
      .toList());

  /// One average per month, oldest first.
  static List<MonthAvg> monthlyAverages(Iterable<WeightEntry> list) {
    final groups = <int, List<double>>{};
    for (final e in list) {
      groups.putIfAbsent(e.date.year * 12 + (e.date.month - 1), () => []).add(e.kg);
    }
    final keys = groups.keys.toList()..sort();
    return [
      for (final k in keys)
        MonthAvg(
          DateTime(k ~/ 12, k % 12 + 1, 1),
          groups[k]!.reduce((a, b) => a + b) / groups[k]!.length,
          groups[k]!.length,
        ),
    ];
  }
}
