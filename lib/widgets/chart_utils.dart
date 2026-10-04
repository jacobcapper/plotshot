import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Android's system font; named explicitly so canvas text matches the UI.
const chartFont = 'Roboto';

/// Evenly spaced "nice" tick values covering [min, max].
List<double> niceTicks(double min, double max, {int target = 4}) {
  if (max <= min) max = min + 1;
  final raw = (max - min) / target;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final step =
      (norm < 1.5
          ? 1
          : norm < 3
          ? 2
          : norm < 7
          ? 5
          : 10) *
      mag;
  final start = (min / step).floor() * step;
  final ticks = <double>[];
  for (var v = start; v <= max + step * 0.5; v += step) {
    ticks.add(double.parse(v.toStringAsFixed(6)));
  }
  return ticks;
}

void paintLabel(
  Canvas canvas,
  String text,
  Offset at, {
  required TextStyle style,
  Alignment align = Alignment.centerLeft,
  Color? background,
  EdgeInsets padding = EdgeInsets.zero,
  double radius = 8,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = tp.width + padding.horizontal;
  final h = tp.height + padding.vertical;
  final dx = at.dx - w * (align.x + 1) / 2;
  final dy = at.dy - h * (align.y + 1) / 2;
  if (background != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, dy, w, h),
        Radius.circular(radius),
      ),
      Paint()..color = background,
    );
  }
  tp.paint(canvas, Offset(dx + padding.left, dy + padding.top));
}

/// Rect of a label as [paintLabel] would place it, for collision checks.
Rect labelRect(
  String text,
  Offset at, {
  required TextStyle style,
  Alignment align = Alignment.centerLeft,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = tp.width + padding.horizontal;
  final h = tp.height + padding.vertical;
  return Rect.fromLTWH(
    at.dx - w * (align.x + 1) / 2,
    at.dy - h * (align.y + 1) / 2,
    w,
    h,
  );
}

void drawDashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double dash = 4,
  double gap = 4,
}) {
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final end = math.min(d + dash, total);
    canvas.drawLine(a + dir * d, a + dir * end, paint);
    d += dash + gap;
  }
}

void drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 6,
  double gap = 5,
}) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(metric.extractPath(d, d + dash), paint);
      d += dash + gap;
    }
  }
}
