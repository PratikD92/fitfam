import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Commented below and using intl.dart directly - Change #06
// import 'package:intl/intl.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:provider/provider.dart';
import '../../core/date_utils.dart';
import '../../models/weight_log.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_scaffold.dart';

const _fieldFill = Color(0xFFF4F7FB);

class _WRow {
  _WRow({required this.id, this.date, String text = ''})
      : ctrl = TextEditingController(text: text);
  final String id;
  DateTime? date; // null = blank "new entry" row
  final TextEditingController ctrl;
}

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final List<_WRow> _rows = [];
  final List<TextEditingController> _ctrls = [];
  late final String _initialJson;
  bool _showErrors = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    final saved = [...context.read<AppState>().weightLog.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final e in saved) {
      _rows.add(_newRow(id: e.id, date: e.date, text: _fmt(e.kg)));
    }
    _rows.insert(0, _newRow()); // blank row for the next entry
    _initialJson = _entriesJson();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  _WRow _newRow({String? id, DateTime? date, String text = ''}) {
    final r = _WRow(
        id: id ?? 'w${DateTime.now().microsecondsSinceEpoch}_${_seq++}',
        date: date,
        text: text);
    _ctrls.add(r.ctrl);
    r.ctrl.addListener(() => _rowChanged(r));
    return r;
  }

  /// Typing a weight into the blank row fills in today's date and opens a
  /// fresh blank row above it.
  void _rowChanged(_WRow r) {
    if (r.ctrl.text.trim().isNotEmpty && r.date == null) {
      r.date = dateOnly(DateTime.now());
      if (!_rows.any((x) => x.date == null)) _rows.insert(0, _newRow());
    }
    setState(() {});
  }

  double? _kg(_WRow r) => double.tryParse(r.ctrl.text.trim());
  bool _valid(double? kg) => kg != null && kg >= 20 && kg <= 300;

  List<WeightEntry> _entries() => [
        for (final r in _rows)
          if (r.date != null && _valid(_kg(r)))
            WeightEntry(id: r.id, date: r.date!, kg: _kg(r)!),
      ];

  String _entriesJson() {
    final list = _entries()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  bool get _isDirty => _entriesJson() != _initialJson;

  void _sortRows() {
    final blanks = _rows.where((r) => r.date == null).toList();
    final dated = _rows.where((r) => r.date != null).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    _rows
      ..clear()
      ..addAll([...blanks, ...dated]);
  }

  Future<void> _pickDate(_WRow r) async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: r.date ?? today,
      firstDate: DateTime(2015),
      lastDate: today, // no future dates
    );
    if (picked != null) {
      setState(() {
        r.date = dateOnly(picked);
        _sortRows();
      });
    }
  }

  Future<void> _save() async {
    final bad = _rows.any((r) => r.date != null && !_valid(_kg(r)));
    if (bad) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('Enter a weight between 20 and 300 kg, or delete the row')));
      return;
    }
    await context.read<AppState>().saveWeightLog(WeightLog(_entries()));
    if (mounted) Navigator.pop(context);
  }

  String? _summary(List<MonthAvg> m) {
    if (m.isEmpty) return null;
    if (m.length == 1) {
      return 'Average in ${DateFormat('MMM yyyy').format(m.first.month)}: '
          '${m.first.avg.toStringAsFixed(1)} kg';
    }
    final first = m.first.avg, last = m.last.avg, d = last - first;
    return '${first.toStringAsFixed(1)} → ${last.toStringAsFixed(1)} kg '
        '(${d > 0 ? '+' : ''}${d.toStringAsFixed(1)} kg)';
  }

  @override
  Widget build(BuildContext context) {
    final months = WeightLog.monthlyAverages(_entries());
    final summary = _summary(months);
    Widget head(String t) => Text(t,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54));

    return AppScaffold(
      title: 'Weight Tracking',
      isDirty: _isDirty,
      onDone: _save,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weight by month (kg)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (summary != null) ...[
                  const SizedBox(height: 2),
                  Text(summary, style: const TextStyle(color: Colors.black54)),
                ],
                const SizedBox(height: 8),
                if (months.isEmpty)
                  const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text('Add your first weight below to see the graph.',
                          style: TextStyle(color: Colors.black54)),
                    ),
                  )
                else
                  _WeightChart(points: months),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                  child: Row(children: [
                    Expanded(flex: 5, child: head('Date')),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: head('Weight')),
                    const SizedBox(width: 48),
                  ]),
                ),
                const Divider(height: 1),
                for (final r in _rows) _row(r),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Type a weight and today\'s date is filled in automatically. '
            'Tap a date to change it. If you add several weights in one month, '
            'the graph shows their average.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _row(_WRow r) {
    final hasDate = r.date != null;
    final error = _showErrors && hasDate && !_valid(_kg(r));
    return Padding(
      key: ValueKey(r.id),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: hasDate ? () => _pickDate(r) : null,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                    color: _fieldFill, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  hasDate ? DateFormat('d MMM yyyy').format(r.date!) : 'Today (auto)',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                      color: hasDate ? Colors.black87 : Colors.black38),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: TextField(
              controller: r.ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                hintText: 'kg',
                suffixText: 'kg',
                fillColor: _fieldFill,
                errorText: error ? 'Invalid' : null,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: hasDate
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.black45,
                    onPressed: () => setState(() => _rows.remove(r)),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatefulWidget {
  const _WeightChart({required this.points});
  final List<MonthAvg> points;
  @override
  State<_WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<_WeightChart> {
  final _scroll = ScrollController();
  int _lastCount = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    // Every month between first and last gets a slot, even without data.
    final first = pts.first.month, last = pts.last.month;
    final months = <DateTime>[];
    for (var m = first; !m.isAfter(last); m = DateTime(m.year, m.month + 1, 1)) {
      months.add(m);
    }
    final byMonth = {for (final p in pts) p.month.year * 12 + p.month.month: p.avg};

    if (months.length != _lastCount) {
      _lastCount = months.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }

    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, cons) {
      final width = math.max(cons.maxWidth, months.length * 64.0 + 40);
      return SizedBox(
        height: 230,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: CustomPaint(
            size: Size(width, 230),
            painter: _ChartPainter(
              months: months,
              byMonth: byMonth,
              line: cs.primary,
              grid: Colors.black12,
              label: Colors.black54,
            ),
          ),
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.months,
    required this.byMonth,
    required this.line,
    required this.grid,
    required this.label,
  });
  final List<DateTime> months;
  final Map<int, double> byMonth;
  final Color line, grid, label;

  void _text(Canvas c, String s, Offset center,
      {double size = 11, FontWeight w = FontWeight.w500, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, fontWeight: w, color: color ?? label)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0, right = 16.0, top = 26.0, bottom = 32.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

    final values = byMonth.values.toList();
    var lo = values.reduce(math.min) - 1;
    var hi = values.reduce(math.max) + 1;
    if (hi - lo < 4) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    lo = lo.floorToDouble();
    hi = hi.ceilToDouble();
    final decimals = (hi - lo) <= 8 ? 1 : 0;

    // grid + y labels
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(canvas, (lo + (hi - lo) * i / 4).toStringAsFixed(decimals),
          Offset(plot.left - 18, y));
    }

    final slot = plot.width / months.length;
    double xOf(int i) => plot.left + slot * (i + 0.5);
    double yOf(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    // x labels
    for (var i = 0; i < months.length; i++) {
      _text(canvas, DateFormat('MMM yy').format(months[i]),
          Offset(xOf(i), plot.bottom + 16));
    }

    // line
    final path = Path();
    var started = false;
    final dots = <Offset>[];
    final vals = <double>[];
    for (var i = 0; i < months.length; i++) {
      final v = byMonth[months[i].year * 12 + months[i].month];
      if (v == null) continue;
      final o = Offset(xOf(i), yOf(v));
      dots.add(o);
      vals.add(v);
      if (!started) {
        path.moveTo(o.dx, o.dy);
        started = true;
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // dots + value labels
    for (var i = 0; i < dots.length; i++) {
      canvas.drawCircle(dots[i], 6, Paint()..color = line);
      canvas.drawCircle(dots[i], 3, Paint()..color = Colors.white);
      _text(canvas, vals[i].toStringAsFixed(1), dots[i] - const Offset(0, 17),
          size: 11.5, w: FontWeight.w800, color: Colors.black87);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
