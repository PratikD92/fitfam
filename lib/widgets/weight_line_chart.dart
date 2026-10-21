import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weight_log.dart';

/// Line graph of monthly average weight. Scrolls sideways when there are
/// many months (starts at the latest month). Optional dashed target line.
class WeightLineChart extends StatelessWidget {
  const WeightLineChart({super.key, required this.months, this.target});
  final List<MonthAvg> months;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (months.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text('Enter a weight below to start your graph.',
            style: TextStyle(color: Colors.black45)),
      );
    }
    final first = months.first.month, last = months.last.month;
    final span = (last.year - first.year) * 12 + (last.month - first.month);

    return LayoutBuilder(builder: (context, box) {
      final minWidth = 44.0 + 24.0 + math.max(span, 1) * 64.0;
      final width = math.max(box.maxWidth, minWidth);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: CustomPaint(
          size: Size(width, 230),
          painter: _ChartPainter(
            months: months,
            target: target,
            span: span,
            color: cs.primary,
          ),
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(
      {required this.months, required this.target, required this.span, required this.color});
  final List<MonthAvg> months;
  final double? target;
  final int span;
  final Color color;

  void _text(Canvas canvas, String s, Offset anchor,
      {double size = 10, FontWeight weight = FontWeight.w500, Color c = Colors.black54,
      bool centerX = false, bool rightAlign = false, bool centerY = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: weight, color: c)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = anchor.dx;
    if (centerX) dx -= tp.width / 2;
    if (rightAlign) dx -= tp.width;
    final dy = centerY ? anchor.dy - tp.height / 2 : anchor.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0, right = 20.0, top = 22.0, bottom = 32.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    var minV = months.map((m) => m.avg).reduce(math.min);
    var maxV = months.map((m) => m.avg).reduce(math.max);
    if (target != null) {
      minV = math.min(minV, target!);
      maxV = math.max(maxV, target!);
    }
    var pad = (maxV - minV) * 0.2;
    if (pad < 1) pad = 1;
    minV -= pad;
    maxV += pad;

    double yOf(double v) => top + h * (1 - (v - minV) / (maxV - minV));
    final first = months.first.month;
    double xOf(DateTime m) {
      if (span == 0) return left + w / 2;
      final i = (m.year - first.year) * 12 + (m.month - first.month);
      return left + w * i / span;
    }

    // grid + y labels
    final grid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final v = minV + (maxV - minV) * k / 4;
      final y = yOf(v);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      _text(canvas, v.toStringAsFixed(1), Offset(left - 6, y), rightAlign: true, centerY: true);
    }

    // target (dashed)
    if (target != null) {
      final y = yOf(target!);
      final dash = Paint()
        ..color = Colors.green.shade400
        ..strokeWidth = 1.5;
      for (var x = left; x < size.width - right; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width - right), y), dash);
      }
      _text(canvas, 'Target ${target!.toStringAsFixed(1)}', Offset(left + 4, y - 14),
          c: Colors.green.shade700, weight: FontWeight.w700);
    }

    // line
    final pts = [for (final m in months) Offset(xOf(m.month), yOf(m.avg))];
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
    }

    // dots, value labels, month labels
    final fmt = DateFormat('MMM yy');
    for (var i = 0; i < months.length; i++) {
      final p = pts[i];
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4.5, Paint()..color = color);
      _text(canvas, months[i].avg.toStringAsFixed(1), Offset(p.dx, p.dy - 20),
          centerX: true, weight: FontWeight.w800, c: Colors.black87);
      _text(canvas, fmt.format(months[i].month), Offset(p.dx, size.height - bottom + 10),
          centerX: true);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
