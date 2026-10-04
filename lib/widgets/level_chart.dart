import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/pk.dart';
import '../logic/units.dart';
import '../models/jab.dart';
import '../theme.dart';
import 'chart_utils.dart';

/// Estimated medication level over time, with a "now" marker, a dashed
/// projection into the future and a drag-to-inspect scrubber.
class LevelChart extends StatefulWidget {
  final List<LevelPoint> points;
  final DateTime now;
  final List<Jab> jabs;
  final double height;

  const LevelChart({
    super.key,
    required this.points,
    required this.now,
    required this.jabs,
    this.height = 220,
  });

  @override
  State<LevelChart> createState() => _LevelChartState();
}

class _LevelChartState extends State<LevelChart> {
  double? _touchX;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          void touch(Offset p) => setState(() => _touchX = p.dx);
          return GestureDetector(
            onHorizontalDragStart: (d) => touch(d.localPosition),
            onHorizontalDragUpdate: (d) => touch(d.localPosition),
            onHorizontalDragEnd: (_) => setState(() => _touchX = null),
            onTapDown: (d) => touch(d.localPosition),
            onTapUp: (_) => setState(() => _touchX = null),
            child: CustomPaint(
              size: Size(c.maxWidth, widget.height),
              painter: _LevelPainter(
                points: widget.points,
                now: widget.now,
                jabs: widget.jabs,
                touchX: _touchX,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  final List<LevelPoint> points;
  final DateTime now;
  final List<Jab> jabs;
  final double? touchX;

  _LevelPainter({
    required this.points,
    required this.now,
    required this.jabs,
    this.touchX,
  });

  static const _axisStyle = TextStyle(
    fontFamily: chartFont,
    color: AppColors.muted,
    fontSize: 11,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const rightPad = 50.0, bottomPad = 22.0, topPad = 34.0;
    final plot = Rect.fromLTRB(
      0,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );
    final t0 = points.first.time.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.time.millisecondsSinceEpoch.toDouble();
    final maxMg = points
        .map((p) => p.mg)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final ticks = niceTicks(0, maxMg <= 0 ? 1 : maxMg * 1.1);
    final yMax = ticks.last;

    double x(DateTime t) =>
        plot.left + (t.millisecondsSinceEpoch - t0) / (t1 - t0) * plot.width;
    double y(double mg) => plot.bottom - mg / yMax * plot.height;

    // Grid + y labels
    final grid = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    for (final v in ticks) {
      final yy = y(v);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
      paintLabel(
        canvas,
        '${formatDose(v)} mg',
        Offset(plot.right + 6, yy),
        style: _axisStyle,
        align: Alignment.centerLeft,
      );
    }

    // X labels: pick a step that fits about five labels.
    final spanDays = (t1 - t0) / Duration.millisecondsPerDay;
    final stepDays = spanDays <= 10
        ? 2
        : spanDays <= 21
        ? 4
        : spanDays <= 45
        ? 7
        : spanDays <= 120
        ? 21
        : (spanDays / 5).ceil();
    final fmt = DateFormat('d MMM');
    var d = DateTime(
      points.first.time.year,
      points.first.time.month,
      points.first.time.day + 1,
    );
    while (d.isBefore(points.last.time)) {
      final xx = x(d);
      if (xx > 16 && xx < plot.right - 16) {
        paintLabel(
          canvas,
          fmt.format(d),
          Offset(xx, plot.bottom + 4),
          style: _axisStyle,
          align: Alignment.topCenter,
        );
      }
      d = DateTime(d.year, d.month, d.day + stepDays);
    }

    // Split into past (solid + fill) and future (dashed).
    final past = Path(), future = Path(), fill = Path();
    var startedFuture = false;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final o = Offset(x(p.time), y(p.mg));
      if (!p.time.isAfter(now)) {
        if (i == 0) {
          past.moveTo(o.dx, o.dy);
          fill.moveTo(o.dx, plot.bottom);
          fill.lineTo(o.dx, o.dy);
        } else {
          past.lineTo(o.dx, o.dy);
          fill.lineTo(o.dx, o.dy);
        }
      } else {
        if (!startedFuture) {
          startedFuture = true;
          if (i > 0) {
            final prev = points[i - 1];
            future.moveTo(x(prev.time), y(prev.mg));
          } else {
            future.moveTo(o.dx, o.dy);
          }
        }
        future.lineTo(o.dx, o.dy);
      }
    }
    final pastEnd = points.lastWhere(
      (p) => !p.time.isAfter(now),
      orElse: () => points.first,
    );
    fill
      ..lineTo(x(pastEnd.time), plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.level.withValues(alpha: 0.35),
            AppColors.level.withValues(alpha: 0.0),
          ],
        ).createShader(plot),
    );
    final line = Paint()
      ..color = AppColors.level
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(past, line);
    drawDashedPath(
      canvas,
      future,
      line..color = AppColors.level.withValues(alpha: 0.6),
    );

    // Jab markers along the bottom.
    for (final j in jabs) {
      if (j.takenAt.millisecondsSinceEpoch < t0 ||
          j.takenAt.millisecondsSinceEpoch > t1) {
        continue;
      }
      final xx = x(j.takenAt);
      canvas.drawCircle(
        Offset(xx, plot.bottom),
        4,
        Paint()..color = AppColors.accent,
      );
    }

    // Now marker
    if (now.millisecondsSinceEpoch >= t0 && now.millisecondsSinceEpoch <= t1) {
      final nx = x(now);
      drawDashedLine(
        canvas,
        Offset(nx, plot.top - 6),
        Offset(nx, plot.bottom),
        Paint()
          ..color = AppColors.muted
          ..strokeWidth = 1,
      );
      final nowMg = _valueAt(now);
      canvas.drawCircle(
        Offset(nx, y(nowMg)),
        5,
        Paint()..color = AppColors.level,
      );
      canvas.drawCircle(
        Offset(nx, y(nowMg)),
        2.5,
        Paint()..color = AppColors.background,
      );
      if (touchX == null) {
        _tooltip(
          canvas,
          size,
          plot,
          nx,
          'Now · ${nowMg.toStringAsFixed(2)} mg',
        );
      }
    }

    // Scrubber
    if (touchX != null) {
      final tx = touchX!.clamp(plot.left, plot.right);
      final t = DateTime.fromMillisecondsSinceEpoch(
        (t0 + (tx - plot.left) / plot.width * (t1 - t0)).round(),
      );
      final mg = _valueAt(t);
      canvas.drawLine(
        Offset(tx, plot.top - 6),
        Offset(tx, plot.bottom),
        Paint()
          ..color = AppColors.text.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(tx, y(mg)), 5, Paint()..color = AppColors.text);
      _tooltip(
        canvas,
        size,
        plot,
        tx,
        '${DateFormat('EEE d MMM, HH:mm').format(t)} · ${mg.toStringAsFixed(2)} mg',
      );
    }
  }

  void _tooltip(Canvas canvas, Size size, Rect plot, double atX, String text) {
    const style = TextStyle(
      fontFamily: chartFont,
      color: AppColors.background,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final r = labelRect(
      text,
      Offset(atX, 2),
      style: style,
      align: Alignment.topCenter,
      padding: pad,
    );
    var dx = 0.0;
    if (r.left < 0) dx = -r.left;
    if (r.right > size.width) dx = size.width - r.right;
    paintLabel(
      canvas,
      text,
      Offset(atX + dx, 2),
      style: style,
      align: Alignment.topCenter,
      background: AppColors.level,
      padding: pad,
    );
  }

  double _valueAt(DateTime t) {
    // Linear interpolation between samples.
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (!t.isAfter(b.time)) {
        final span = b.time.difference(a.time).inMilliseconds;
        if (span == 0) return b.mg;
        final f = t.difference(a.time).inMilliseconds / span;
        return a.mg + (b.mg - a.mg) * f.clamp(0, 1);
      }
    }
    return points.last.mg;
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.points != points || old.touchX != touchX || old.now != now;
}
