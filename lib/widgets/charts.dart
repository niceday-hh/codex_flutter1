import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';

class TrendPoint {
  const TrendPoint({required this.label, required this.amount});
  final String label;
  final double amount;
}

class InteractiveTrendChart extends StatelessWidget {
  const InteractiveTrendChart({
    super.key,
    required this.points,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 210,
  });

  final List<TrendPoint> points;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${points.length}_${points.fold<double>(0, (s, p) => s + p.amount)}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (points.isEmpty) return;
            const left = 24.0;
            const right = 12.0;
            final width = context.size?.width ?? 1;
            final usable = math.max(1, width - left - right);
            final normalized = ((details.localPosition.dx - left) / usable).clamp(0.0, 1.0);
            final index = (normalized * math.max(0, points.length - 1)).round();
            onSelected(index.clamp(0, points.length - 1));
          },
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                points: points,
                selectedIndex: selectedIndex,
                progress: progress,
                textColor: Theme.of(context).textTheme.bodySmall?.color ?? AppPalette.secondary,
                lineColor: AppPalette.primary,
                gridColor: Theme.of(context).dividerColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.selectedIndex,
    required this.progress,
    required this.textColor,
    required this.lineColor,
    required this.gridColor,
  });

  final List<TrendPoint> points;
  final int selectedIndex;
  final double progress;
  final Color textColor;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 24.0;
    const right = 12.0;
    const top = 34.0;
    const bottom = 30.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final maxValue = math.max(1.0, points.map((e) => e.amount).fold<double>(0, (maxValue, value) => math.max(maxValue, value)) * 1.18);

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.68)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    Offset pointAt(int index) {
      final x = points.length == 1 ? left + chartWidth / 2 : left + chartWidth * index / (points.length - 1);
      final value = points[index].amount * progress;
      final y = top + chartHeight - (value / maxValue) * chartHeight;
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final fillPath = Path.from(path)
      ..lineTo(size.width - right, top + chartHeight)
      ..lineTo(left, top + chartHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: 0.18), lineColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight)),
    );

    final labelEvery = points.length <= 7 ? 1 : (points.length <= 12 ? 2 : math.max(1, (points.length / 6).round()));
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      final hasValue = points[i].amount > 0;
      canvas.drawCircle(
        p,
        hasValue ? 4.1 : 3.1,
        Paint()
          ..color = hasValue ? lineColor : gridColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill,
      );
      if (hasValue) {
        canvas.drawCircle(
          p,
          4.1,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      if (i % labelEvery == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(text: points[i].label, style: TextStyle(fontSize: 10.5, color: textColor)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(p.dx - tp.width / 2, top + chartHeight + 9));
      }
    }

    final selected = selectedIndex.clamp(0, points.length - 1);
    final selectedPoint = pointAt(selected);
    canvas.drawLine(
      Offset(selectedPoint.dx, top),
      Offset(selectedPoint.dx, top + chartHeight),
      Paint()
        ..color = lineColor.withValues(alpha: 0.45)
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(selectedPoint, 12, Paint()..color = lineColor.withValues(alpha: 0.15));
    canvas.drawCircle(selectedPoint, 6.5, Paint()..color = lineColor);
    canvas.drawCircle(selectedPoint, 4.1, Paint()..color = Colors.white);

    final amount = _money(points[selected].amount);
    final tooltip = '${points[selected].label} · ¥$amount';
    final textPainter = TextPainter(
      text: const TextSpan(),
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: tooltip,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
    );
    textPainter.layout();
    final width = textPainter.width + 20;
    final rectLeft = (selectedPoint.dx - width / 2).clamp(4.0, size.width - width - 4);
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(rectLeft, 2, width, 27), const Radius.circular(14));
    canvas.drawRRect(rect, Paint()..color = lineColor);
    textPainter.paint(canvas, Offset(rectLeft + 10, 8));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.progress != progress ||
      oldDelegate.textColor != textColor ||
      oldDelegate.gridColor != gridColor;
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.items,
    required this.total,
    this.size = 138,
    this.centerLabel = '总支出',
  });

  final List<CategorySummary> items;
  final double total;
  final double size;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(items: items, total: total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total == 0 ? '¥0' : '¥${_money(total)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(centerLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.items, required this.total});
  final List<CategorySummary> items;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 19
      ..strokeCap = StrokeCap.butt;
    if (total <= 0 || items.isEmpty) {
      paint.color = const Color(0xFFECE5DB);
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final item in items.take(7)) {
      final sweep = math.pi * 2 * item.amount / total;
      paint.color = colorForCategory(item.name);
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.items != items || oldDelegate.total != total;
}

String _money(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
