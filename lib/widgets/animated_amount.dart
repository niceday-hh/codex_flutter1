import 'package:flutter/material.dart';

// Only the scale animates: the displayed value is never an old/interpolated amount.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;
  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}
class _AnimatedAmountState extends State<AnimatedAmount> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), value: 1);
  @override
  void didUpdateWidget(covariant AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (MediaQuery.disableAnimationsOf(context)) _pulse.value = 1;
      else _pulse.forward(from: 0);
    }
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: AnimatedBuilder(
    animation: _pulse,
    child: Text(widget.text, style: widget.style, maxLines: 1),
    builder: (_, child) => Transform.scale(alignment: Alignment.centerRight,
      scale: 1 + .025 * (1 - Curves.easeOutCubic.transform(_pulse.value)), child: child)));
}
