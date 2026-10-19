import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/date_utils.dart';
import '../../core/progress_engine.dart';
import '../../core/theme.dart';
import '../../models/activity_plan.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/goal_progress_card.dart';

const _shortNames = {
  'steps': 'Steps',
  'strength': 'Strength',
  'cardio': 'Cardio',
  'cycling': 'Cycle',
  'elliptical': 'Elliptical',
  'yoga': 'Yoga',
};

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    context.read<AppState>().ensureSnapshots();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Why this day can't be changed, or null if it can.
  String? _blockReason(DayInfo d) {
    if (d.isFuture) return 'Future days can\'t be marked';
    if (!d.editable) return 'This day is before your current goal started';
    if (!d.hasPlan) return 'No exercise planned on this day';
    return null;
  }

  void _onTap(DayInfo d) {
    final reason = _blockReason(d);
    if (reason != null) return _snack(reason);
    if (d.rest) return _snack('Rest day. Long press to remove it.');
    HapticFeedback.lightImpact();
    context.read<AppState>().toggleDone(d.date);
  }

  Future<void> _onLongPress(DayInfo d) async {
    final reason = _blockReason(d);
    if (reason != null) return _snack(reason);
    final isRest = d.rest;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isRest ? 'Remove Rest day?' : 'Mark as Rest day?'),
        content: Text(isRest
            ? 'This day will count as a normal planned day again.'
            : 'This day won\'t count as missed and won\'t affect your goal date.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<AppState>().setRest(d.date, !isRest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final engine = state.engine();
    if (engine == null) {
      return AppScaffold(title: 'Progress', body: const SizedBox());
    }

    final today = engine.today;
    final currentMonth = DateTime(today.year, today.month, 1);
    final t = parseKey(engine.goal.trackingStart);
    final firstMonth = DateTime(t.year, t.month, 1);
    final canPrev = _month.isAfter(firstMonth);
    final canNext = _month.isBefore(currentMonth);
    final isCurrent = _month == currentMonth;
    final (doneCount, plannedCount) = engine.monthStats(_month);

    return AppScaffold(
      title: 'Progress',
      onDone: () => Navigator.pop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(children: [
            _StatTile(emoji: '🔥', label: 'Streak', value: '${engine.currentStreak()} d'),
            const SizedBox(width: 8),
            _StatTile(emoji: '🏆', label: 'Record', value: '${engine.bestStreak()} d'),
            const SizedBox(width: 8),
            _StatTile(
                emoji: '📅',
                label: isCurrent ? 'This month' : DateFormat('MMM').format(_month),
                value: '$doneCount/$plannedCount'),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tap a day to cross it when you have exercised.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Long Press on date to mark as \'Rest Day\'',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: canPrev
                  ? () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1))
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(DateFormat('MMMM yyyy').format(_month),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            if (!isCurrent)
              TextButton(
                  onPressed: () => setState(() => _month = currentMonth),
                  child: const Text('Today')),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canNext
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1))
                  : null,
            ),
          ]),
          Row(children: [
            for (final w in weekdayShort)
              Expanded(
                child: Center(
                  child: Text(w,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          ..._weeks(engine),
          const SizedBox(height: 6),
          const _Legend(),
          const SizedBox(height: 16),
          GoalProgressCard(summary: engine.summary()),
        ],
      ),
    );
  }

  List<Widget> _weeks(ProgressEngine engine) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(first.weekday - 1, null),
      for (var d = 1; d <= daysInMonth; d++) DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [
      for (var i = 0; i < cells.length; i += 7)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in cells.sublist(i, i + 7))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: c == null
                          ? const SizedBox.shrink()
                          : _DayCell(
                              info: engine.dayInfo(c),
                              onTap: _onTap,
                              onLongPress: _onLongPress,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.emoji, required this.label, required this.value});
  final String emoji, label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text('$emoji  $value',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
      );
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.info, required this.onTap, required this.onLongPress});
  final DayInfo info;
  final void Function(DayInfo) onTap;
  final void Function(DayInfo) onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locked = !info.editable;
    final bg = info.isFuture ? const Color(0xFFECEFF4) : Colors.white;
    final opacity = info.isFuture ? 0.5 : (locked ? 0.6 : 1.0);

    final dateText = Text('${info.date.day}',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: info.isToday
                ? Colors.white
                : (info.missed ? Colors.red.shade400 : Colors.black87)));

    Widget pill(String text, Color c, {double o = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Opacity(
            opacity: o,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
              decoration: BoxDecoration(
                  color: c.withOpacity(0.16), borderRadius: BorderRadius.circular(4)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text,
                    style: TextStyle(
                        fontSize: 8.5, fontWeight: FontWeight.w800, color: c)),
              ),
            ),
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(info),
      onLongPress: () => onLongPress(info),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: info.isToday ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Opacity(
              opacity: opacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: info.isToday
                        ? BoxDecoration(color: cs.primary, shape: BoxShape.circle)
                        : null,
                    child: dateText,
                  ),
                  const SizedBox(height: 3),
                  if (info.rest) pill('Rest', restColor),
                  for (final a in info.planned)
                    pill(_shortNames[a.id] ?? a.label, activityColors[a.id]!,
                        o: info.rest ? 0.4 : 1),
                ],
              ),
            ),
          ),
          if (info.done)
            Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _CrossPainter()))),
        ],
      ),
    );
  }
}

/// Semi-transparent X so the activity names underneath stay visible.
class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const m = 5.0;
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final d in activityDefs)
              dot(activityColors[d.id]!, _shortNames[d.id] ?? d.label),
            dot(restColor, 'Rest'),
          ]),
          const SizedBox(height: 8),
          const Text('✕ = exercise done   •   red date = missed day',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}
