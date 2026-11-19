import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sade yildiz alani: yavas akan, yanip sonen noktalar.
/// Sistem "animasyonlari azalt" derse sabit cizilir.
class Starfield extends StatefulWidget {
  const Starfield({super.key, required this.child, required this.bg, required this.accent, required this.accent2});

  final Widget child;
  final Color bg;
  final Color accent;
  final Color accent2;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final List<_Star> _stars = () {
    final r = math.Random(11);
    return List.generate(
      140,
      (_) => _Star(r.nextDouble(), r.nextDouble(), r.nextDouble() * 0.9 + 0.1, r.nextDouble() * 6.28),
    );
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: widget.bg,
            gradient: RadialGradient(
              center: const Alignment(0.7, -1.0),
              radius: 1.3,
              colors: [widget.accent2.withValues(alpha: 0.16), Colors.transparent],
            ),
          ),
        ),
        IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _StarPainter(_stars, _c.value * 60000, widget.accent),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Star {
  _Star(this.x, this.y, this.z, this.tw);
  final double x, y, z, tw;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.t, this.accent);
  final List<_Star> stars;
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in stars) {
      final a = (0.35 + 0.45 * math.sin(t / 900 + s.tw)) * s.z;
      p.color = (s.z > 0.8 ? accent : const Color(0xFFCFE3FF)).withValues(alpha: a.clamp(0.1, 1.0));
      final y = ((s.y + t / 1000 * s.z * 0.004) % 1.0) * size.height;
      canvas.drawRect(Rect.fromLTWH(s.x * size.width, y, s.z * 1.8, s.z * 1.8), p);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}
