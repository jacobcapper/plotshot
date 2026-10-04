import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../logic/units.dart';
import '../models/jab.dart';
import '../models/weight_entry.dart';
import '../theme.dart';
import 'chart_utils.dart';
import 'common.dart';

/// Weight over time. Each stretch of the line is coloured by the dose in
/// effect, with a label where the dose changes.
class WeightChart extends StatefulWidget {
  final List<WeightEntry> weights;
  final List<Jab> jabs; // oldest first
  final WeightUnit unit;
  final double? goalKg;
  final double height;

  const WeightChart({
    super.key,
    required this.weights,
    required this.jabs,
    required this.unit,
    this.goalKg,
    this.height = 300,
  });

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          final painter = _WeightPainter(
            weights: widget.weights,
            jabs: widget.jabs,
            unit: widget.unit,
            goalKg: widget.goalKg,
            selected: _selected,
          );
          void pick(Offset p) {
            final i = painter.nearestIndex(
              Size(c.maxWidth, widget.height),
              p.dx,
            );
            if (i != _selected) setState(() => _selected = i);
          }

          return GestureDetector(
            onTapDown: (d) => pick(d.localPosition),
            onHorizontalDragStart: (d) => pick(d.localPosition),
            onHorizontalDragUpdate: (d) => pick(d.localPosition),
            onHorizontalDragEnd: (_) => setState(() => _selected = null),
            onTapUp: (_) => setState(() => _selected = null),
            child: CustomPaint(
              size: Size(c.maxWidth, widget.height),
              painter: painter,
            ),
          );
        },
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<WeightEntry> weights;
  final List<Jab> jabs;
  final WeightUnit unit;
  final double? goalKg;
  final int? selected;

  _WeightPainter({
    required this.weights,
    required this.jabs,
    required this.unit,
    this.goalKg,
    this.selected,
  });

  static const _rightPad = 52.0, _bottomPad = 24.0, _topPad = 36.0;
  static const _axis = TextStyle(
    fontFamily: chartFont,
    color: AppColors.muted,
    fontSize: 11,
  );

  double _display(double kg) => unit == WeightUnit.kg ? kg : kgToLb(kg);

  Rect _plot(Size size) => Rect.fromLTRB(
    14,
    _topPad,
    size.width - _rightPad,
    size.height - _bottomPad,
  );

  (double, double) _timeRange() {
    var t0 = weights.first.date.millisecondsSinceEpoch.toDouble();
    var t1 = weights.last.date.millisecondsSinceEpoch.toDouble();
    if (t1 - t0 < Duration.millisecondsPerDay) {
      t0 -= Duration.millisecondsPerDay * 3;
      t1 += Duration.millisecondsPerDay * 3;
    }
    return (t0, t1);
  }

  double _x(Rect plot, double t0, double t1, DateTime d) =>
      plot.left + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * plot.width;

  int? nearestIndex(Size size, double dx) {
    if (weights.isEmpty) return null;
    final plot = _plot(size);
    final (t0, t1) = _timeRange();
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < weights.length; i++) {
      final dist = (_x(plot, t0, t1, weights[i].date) - dx).abs();
      if (dist < bestDist) {
        best = i;
        bestDist = dist;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;
    final plot = _plot(size);
    final (t0, t1) = _timeRange();
    final values = weights.map((w) => _display(w.kg)).toList();
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    final pad = ((hi - lo) * 0.1).clamp(0.5, double.infinity);
    final ticks = niceTicks(lo - pad, hi + pad);
    lo = ticks.first;
    hi = ticks.last;

    double x(DateTime d) => _x(plot, t0, t1, d);
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    final unitLabel = unit == WeightUnit.kg ? 'kg' : 'lb';
    for (final v in ticks) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), grid);
      paintLabel(
        canvas,
        '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} $unitLabel',
        Offset(plot.right + 6, y(v)),
        style: _axis,
      );
    }

    // Goal line if it falls inside the visible range.
    if (goalKg != null) {
      final g = _display(goalKg!);
      if (g >= lo && g <= hi) {
        drawDashedLine(
          canvas,
          Offset(plot.left, y(g)),
          Offset(plot.right, y(g)),
          Paint()
            ..color = AppColors.success.withValues(alpha: 0.7)
            ..strokeWidth = 1.2,
        );
        paintLabel(
          canvas,
          'Goal',
          Offset(plot.left + 2, y(g) - 2),
          style: const TextStyle(
            fontFamily: chartFont,
            color: AppColors.success,
            fontSize: 11,
          ),
          align: Alignment.bottomLeft,
        );
      }
    }

    // Month boundaries
    final first = DateTime.fromMillisecondsSinceEpoch(t0.round());
    var m = DateTime(first.year, first.month + 1);
    final spanDays = (t1 - t0) / Duration.millisecondsPerDay;
    final monthStep = spanDays > 300 ? 3 : (spanDays > 150 ? 2 : 1);
    final monthFmt = DateFormat(spanDays > 300 ? 'MMM yy' : 'MMM yyyy');
    while (m.millisecondsSinceEpoch < t1) {
      final mx = x(m);
      drawDashedLine(
        canvas,
        Offset(mx, plot.top),
        Offset(mx, plot.bottom),
        Paint()
          ..color = AppColors.outline
          ..strokeWidth = 1,
        dash: 3,
        gap: 3,
      );
      paintLabel(
        canvas,
        monthFmt.format(m),
        Offset(mx + 4, plot.bottom + 4),
        style: _axis,
        align: Alignment.topLeft,
      );
      m = DateTime(m.year, m.month + monthStep);
    }
    if (spanDays < 40) {
      paintLabel(
        canvas,
        DateFormat('d MMM').format(weights.first.date),
        Offset(plot.left, plot.bottom + 4),
        style: _axis,
        align: Alignment.topLeft,
      );
    }

    // Line segments coloured by dose in effect at each point.
    final allDoses = jabs.map((j) => j.doseMg);
    Jab? doseAt(DateTime day) =>
        jabInEffect(jabs, DateTime(day.year, day.month, day.day, 23, 59));
    final pts = [
      for (var i = 0; i < weights.length; i++)
        Offset(x(weights[i].date), y(values[i])),
    ];
    final colors = [
      for (final w in weights)
        () {
          final j = doseAt(w.date);
          return j == null ? AppColors.muted : doseColor(j.doseMg, allDoses);
        }(),
    ];
    for (var i = 1; i < pts.length; i++) {
      canvas.drawLine(
        pts[i - 1],
        pts[i],
        Paint()
          ..color = colors[i]
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 5, Paint()..color = colors[i]);
      canvas.drawCircle(pts[i], 2.5, Paint()..color = AppColors.background);
    }

    // Dose labels where the dose changes, skipping any that would overlap.
    const labelStyle = TextStyle(
      fontFamily: chartFont,
      color: AppColors.background,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    const labelPad = EdgeInsets.symmetric(horizontal: 7, vertical: 3);
    final placed = <Rect>[];
    double? prevDose;
    for (var i = 0; i < weights.length; i++) {
      final j = doseAt(weights[i].date);
      if (j == null || j.doseMg == prevDose) continue;
      prevDose = j.doseMg;
      final text = '${formatDose(j.doseMg)}mg';
      final at = pts[i] + const Offset(0, -10);
      final r = labelRect(
        text,
        at,
        style: labelStyle,
        align: Alignment.bottomCenter,
        padding: labelPad,
      );
      final shift = r.left < 0
          ? -r.left
          : (r.right > size.width ? size.width - r.right : 0.0);
      final shifted = r.shift(Offset(shift, 0));
      if (placed.any((p) => p.overlaps(shifted.inflate(2)))) continue;
      placed.add(shifted);
      paintLabel(
        canvas,
        text,
        at + Offset(shift, 0),
        style: labelStyle,
        align: Alignment.bottomCenter,
        background: colors[i],
        padding: labelPad,
      );
    }

    if (selected != null && selected! < weights.length) {
      final p = pts[selected!];
      canvas.drawLine(
        Offset(p.dx, plot.top - 8),
        Offset(p.dx, plot.bottom),
        Paint()
          ..color = AppColors.text.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      final w = weights[selected!];
      final text =
          '${DateFormat('d MMM yyyy').format(w.date)} · ${formatWeight(w.kg, unit)}';
      const style = TextStyle(
        fontFamily: chartFont,
        color: AppColors.background,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );
      const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      final r = labelRect(
        text,
        Offset(p.dx, 2),
        style: style,
        align: Alignment.topCenter,
        padding: pad,
      );
      final dx = r.left < 0
          ? -r.left
          : (r.right > size.width ? size.width - r.right : 0.0);
      paintLabel(
        canvas,
        text,
        Offset(p.dx + dx, 2),
        style: style,
        align: Alignment.topCenter,
        background: AppColors.text,
        padding: pad,
      );
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) =>
      old.weights != weights ||
      old.jabs != jabs ||
      old.unit != unit ||
      old.selected != selected ||
      old.goalKg != goalKg;
}
