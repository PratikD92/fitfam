import 'dart:async';
import 'package:flutter/material.dart';
import '../core/config.dart';
import '../models/timetable.dart';

/// "Next: Lunch at 13:00 (in 2h 10m)". Refreshes every 30 seconds.
class NextUpLine extends StatefulWidget {
  const NextUpLine({super.key, required this.timetable, this.onTap});
  final Timetable timetable;
  final VoidCallback? onTap;

  @override
  State<NextUpLine> createState() => _NextUpLineState();
}

class _NextUpLineState extends State<NextUpLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _in(Duration d) {
    final mins = (d.inSeconds / 60).ceil();
    if (mins < 1) return 'now';
    final h = mins ~/ 60, m = mins % 60;
    if (h == 0) return 'in ${m}m';
    return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final next = widget.timetable.nextUp(DateTime.now());
    if (next == null) return const SizedBox.shrink();
    final label = AppConfig.instance.timetableRow(next.entry.id).label;
    final when = _in(next.when.difference(DateTime.now()));
    final text = next.isTomorrow
        ? 'Next: $label at ${next.entry.time} (tomorrow, $when)'
        : 'Next: $label at ${next.entry.time} ($when)';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.schedule, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}
