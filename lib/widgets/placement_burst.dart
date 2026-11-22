import 'dart:math';

import 'package:flutter/material.dart';

/// A short celebration overlay for one correctly placed chip: a soft ring
/// and a few sparks that fade in ~300 ms. The overlay ignores pointers and
/// never changes the chip size, so drag targets never shift mid-gesture.
Widget withPlacementBurst({
  required Widget chip,
  required bool active,
  required int serial,
  bool reduceMotion = false,
}) {
  if (!active) return chip;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      chip,
      Positioned.fill(
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(serial),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: reduceMotion ? 150 : 300),
            builder: (context, t, _) {
              return CustomPaint(
                painter: _PlacementBurstPainter(
                  opacity: 1 - t,
                  expansion: reduceMotion ? 0 : t,
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

/// Paints 5 sparks flying outward from the chip edge plus a fading ring.
class _PlacementBurstPainter extends CustomPainter {
  final double opacity; // 1 -> 0
  final double expansion; // 0 -> 1

  _PlacementBurstPainter({required this.opacity, required this.expansion});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.amber.withValues(alpha: opacity);

    // Fading ring hugging the chip edge.
    canvas.drawCircle(center, radius * (1 + 0.35 * expansion), paint);

    // Sparks at fixed angles so the burst is deterministic per frame.
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.amber.withValues(alpha: opacity);
    for (var i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * pi + 0.4;
      final distance = radius + 4 + 10 * expansion;
      canvas.drawCircle(
        center + Offset(cos(angle), sin(angle)) * distance,
        2.2 * (1 - expansion * 0.6),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlacementBurstPainter old) =>
      old.opacity != opacity || old.expansion != expansion;
}
