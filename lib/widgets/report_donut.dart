import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';

const _reportPalette = <Color>[
  Color(0xFFF7AF3A),
  Color(0xFF4AB1E7),
  Color(0xFFF36F8C),
  Color(0xFF8E7CF5),
  Color(0xFF42C7A3),
  Color(0xFFFF8B5F),
  Color(0xFF5C8DF6),
  Color(0xFFE47AD9),
  Color(0xFF80C263),
  Color(0xFFC7A15E),
  Color(0xFF4CC1C7),
  Color(0xFFFB6D60),
];

Color reportPaletteColor(int index) =>
    _reportPalette[index.abs() % _reportPalette.length];

class ReportDonutChart extends StatelessWidget {
  const ReportDonutChart({
    super.key,
    required this.items,
    required this.total,
    this.size = 144,
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
        painter: _ReportDonutPainter(items: items, total: total),
        child: Center(
          child: Container(
            width: size * 0.54,
            height: size * 0.54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    total <= 0 ? '¥0' : '¥${_money(total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  centerLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDonutPainter extends CustomPainter {
  _ReportDonutPainter({required this.items, required this.total});

  final List<CategorySummary> items;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEDE7DE);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (total <= 0 || items.isEmpty) return;

    final visible = <CategorySummary>[];
    if (items.length <= 8) {
      visible.addAll(items);
    } else {
      visible.addAll(items.take(7));
      visible.add(CategorySummary(
        '其他',
        items.skip(7).fold<double>(0, (sum, item) => sum + item.amount),
        items.skip(7).fold<int>(0, (sum, item) => sum + item.count),
      ));
    }

    const gap = 0.025;
    var start = -math.pi / 2;
    for (var index = 0; index < visible.length; index++) {
      final item = visible[index];
      final rawSweep = math.pi * 2 * item.amount / total;
      final sweep = math.max(0.0, rawSweep - gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = reportPaletteColor(index);
      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);
      start += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ReportDonutPainter oldDelegate) =>
      oldDelegate.items != items || oldDelegate.total != total;
}

String _money(double value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '');
