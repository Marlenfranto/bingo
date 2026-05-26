import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One-shot confetti burst. Drops small colored rectangles that launch from
/// the widget's top edge with random angles, fall under simulated gravity,
/// and fade out over [duration]. Cheap enough for a few hundred particles
/// at 60 fps because each particle uses a closed-form parametric trajectory
/// (no per-frame physics).
///
/// Drop into a `Stack` (typically `Positioned.fill`) alongside whatever the
/// confetti is celebrating.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.particleCount = 28,
    this.duration = const Duration(milliseconds: 2400),
    this.colors = const [
      AppColors.accent,
      Colors.white,
      AppColors.accentDark,
    ],
    this.gravity = 220,
    this.spread = 1.4,
    this.baseSpeed = 90,
    this.speedVariance = 140,
  });

  /// How many particles to render. ~28–40 is plenty for a card-sized burst;
  /// crank higher for full-screen scenes.
  final int particleCount;

  /// Total flight time. Particles within this window are scaled by their
  /// per-particle [_life] so some die early and the burst feels organic.
  final Duration duration;

  /// Colors to cycle through across particles.
  final List<Color> colors;

  /// Downward pixel pull (px). Higher = faster fall.
  final double gravity;

  /// Maximum lateral angle off vertical (radians).
  final double spread;

  /// Initial launch speed (px/sec equivalent).
  final double baseSpeed;

  /// Per-particle speed jitter added on top of [baseSpeed].
  final double speedVariance;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _ConfettiPainter(
            progress: _c.value,
            count: widget.particleCount,
            colors: widget.colors,
            gravity: widget.gravity,
            spread: widget.spread,
            baseSpeed: widget.baseSpeed,
            speedVariance: widget.speedVariance,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.count,
    required this.colors,
    required this.gravity,
    required this.spread,
    required this.baseSpeed,
    required this.speedVariance,
  });

  final double progress;
  final int count;
  final List<Color> colors;
  final double gravity;
  final double spread;
  final double baseSpeed;
  final double speedVariance;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      // Stable per-particle randomness via index seeding — same burst every
      // paint at the same `progress`, so the painter stays repaint-friendly.
      final r = math.Random(i * 9301 + 49297);
      final lane = r.nextDouble();
      final side = i.isEven ? -1.0 : 1.0;
      final angle = (r.nextDouble() - 0.5) * spread + side * 0.4;
      final speed = baseSpeed + r.nextDouble() * speedVariance;
      final life = 0.6 + r.nextDouble() * 0.4;
      final localT = (progress / life).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final x0 = lane * size.width;
      // Parametric trajectory: launch upward + sideways, gravity drags down.
      final dx = math.sin(angle) * speed * localT;
      final dy =
          -math.cos(angle) * speed * localT + gravity * localT * localT;

      final rot = (r.nextDouble() * 6) + progress * 6;
      paint.color =
          colors[i % colors.length].withOpacity((1 - localT).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x0 + dx, dy);
      canvas.rotate(rot);
      canvas.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
