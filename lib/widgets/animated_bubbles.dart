import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Soft floating bubbles that slowly drift upward and fade in/out.
/// Put it inside a Stack (usually as `Positioned.fill`) on top of a
/// dark/gradient background. It ignores touches, so buttons stay tappable.
class AnimatedBubbles extends StatefulWidget {
  final int count;
  final Color color;
  final int seed;

  const AnimatedBubbles({
    super.key,
    this.count = 8,
    this.color = Colors.white,
    this.seed = 7,
  });

  @override
  State<AnimatedBubbles> createState() => _AnimatedBubblesState();
}

class _AnimatedBubblesState extends State<AnimatedBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Bubble> _bubbles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    final rnd = math.Random(widget.seed);
    _bubbles = List.generate(widget.count, (i) {
      return _Bubble(
        x: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        radius: 3 + rnd.nextDouble() * 11,
        cycles: 1 + rnd.nextInt(2), // whole number => seamless loop
        sway: 4 + rnd.nextDouble() * 12,
        opacity: 0.025 + rnd.nextDouble() * 0.055,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BubblePainter(_controller, _bubbles, widget.color),
        ),
      ),
    );
  }
}

class _Bubble {
  final double x;
  final double phase;
  final double radius;
  final int cycles;
  final double sway;
  final double opacity;

  const _Bubble({
    required this.x,
    required this.phase,
    required this.radius,
    required this.cycles,
    required this.sway,
    required this.opacity,
  });
}

class _BubblePainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Bubble> bubbles;
  final Color color;

  _BubblePainter(this.animation, this.bubbles, this.color)
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final b in bubbles) {
      final t = (animation.value * b.cycles + b.phase) % 1.0;
      final y = size.height * (1.1 - 1.2 * t);
      final x = size.width * b.x +
          math.sin((t + b.phase) * 2 * math.pi) * b.sway;
      final fade = math.sin(t * math.pi); // fade in at bottom, out at top
      final a = b.opacity * fade;

      fill.color = color.withOpacity(a);
      ring.color = color.withOpacity((a * 1.2).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), b.radius, fill);
      canvas.drawCircle(Offset(x, y), b.radius, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => false;
}