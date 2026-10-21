import '../core/config.dart';

/// Next time (today or tomorrow) the given minute-of-day occurs after [now].
/// Negative or >1440 values wrap, so "30 min before 00:10" works.
DateTime nextOccurrenceOf(int minutesOfDay, DateTime now) {
  var fire = DateTime(now.year, now.month, now.day).add(Duration(minutes: minutesOfDay));
  if (!fire.isAfter(now)) {
    fire = DateTime(now.year, now.month, now.day + 1).add(Duration(minutes: minutesOfDay));
  }
  return fire;
}

class TimetableEntry {
  final String id;
  String time; // "HH:mm", 24h
  bool reminderOn;
  TimetableEntry({required this.id, required this.time, this.reminderOn = false});

  int get hour => int.parse(time.split(':')[0]);
  int get minute => int.parse(time.split(':')[1]);
  int get minutesOfDay => hour * 60 + minute;

  TimetableEntry copy() => TimetableEntry(id: id, time: time, reminderOn: reminderOn);

  Map<String, dynamic> toJson() => {'id': id, 'time': time, 'reminderOn': reminderOn};
  factory TimetableEntry.fromJson(Map<String, dynamic> j) => TimetableEntry(
      id: j['id'] as String,
      time: j['time'] as String,
      reminderOn: j['reminderOn'] as bool);
}

class NextUp {
  final TimetableEntry entry;
  final DateTime when;
  final bool isTomorrow;
  const NextUp(this.entry, this.when, this.isTomorrow);
}

/// The day's schedule. Rows and defaults come from config.json "timetable".
class Timetable {
  final List<TimetableEntry> entries;
  Timetable(this.entries);

  factory Timetable.defaults() => Timetable(AppConfig.instance.timetableRows
      .map((r) => TimetableEntry(id: r.id, time: r.defaultTime))
      .toList());

  Timetable copy() => Timetable(entries.map((e) => e.copy()).toList());

  Map<String, dynamic> toJson() => {'entries': entries.map((e) => e.toJson()).toList()};

  /// Saved data is merged with config rows, so rows added to config later appear.
  factory Timetable.fromJson(Map<String, dynamic> j) {
    final saved = {
      for (final e in j['entries'] as List)
        (e as Map<String, dynamic>)['id'] as String: TimetableEntry.fromJson(e)
    };
    return Timetable(AppConfig.instance.timetableRows
        .map((r) => saved[r.id] ?? TimetableEntry(id: r.id, time: r.defaultTime))
        .toList());
  }

  /// Rows in time order. Sleep after midnight (earlier than Wake up) goes last.
  List<TimetableEntry> sortedEntries() {
    var wake = entries.first.minutesOfDay;
    for (final e in entries) {
      if (e.id == 'wake') wake = e.minutesOfDay;
    }
    int key(TimetableEntry e) =>
        (e.id == 'sleep' && e.minutesOfDay <= wake) ? e.minutesOfDay + 1440 : e.minutesOfDay;
    final list = [...entries];
    list.sort((a, b) {
      final c = key(a).compareTo(key(b));
      return c != 0 ? c : entries.indexOf(a).compareTo(entries.indexOf(b));
    });
    return list;
  }

  /// The next scheduled item after [now] (wraps to tomorrow).
  NextUp? nextUp(DateTime now) {
    NextUp? best;
    for (final e in entries) {
      var when = DateTime(now.year, now.month, now.day, e.hour, e.minute);
      var tomorrow = false;
      if (!when.isAfter(now)) {
        when = DateTime(now.year, now.month, now.day + 1, e.hour, e.minute);
        tomorrow = true;
      }
      if (best == null || when.isBefore(best.when)) best = NextUp(e, when, tomorrow);
    }
    return best;
  }
}
