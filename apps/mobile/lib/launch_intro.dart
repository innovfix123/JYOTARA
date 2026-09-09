import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Restores local state while the first Flutter frame is already visible.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({
    super.key,
    required this.initialization,
    required this.child,
  });
  final Future<void>? initialization;
  final Widget child;

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  Future<void> _start() async {
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) _animation.value = 1;
    await Future.wait([
      widget.initialization ?? Future<void>.value(),
      if (!reduced) _animation.forward(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return Scaffold(
      backgroundColor: const Color(0xFF21100F),
      body: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final logo = const Interval(
              0,
              .35,
              curve: Curves.easeOutCubic,
            ).transform(_animation.value);
            final name = const Interval(
              .3,
              .85,
              curve: Curves.easeOutCubic,
            ).transform(_animation.value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: logo,
                  child: Transform.scale(
                    scale: .85 + .15 * logo,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE6B85C), Color(0xFF974D2C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE6B85C)
                                .withValues(alpha: .22 * logo),
                            blurRadius: 60,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.nightlight_round,
                        size: 54,
                        color: Color(0xFFFFF8DE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: name,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - name)),
                    child: const Text(
                      'Jyotara',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: Color(0xFFF7E8CA),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Slow breathing movement behind the welcome content; honors reduced motion.
class WelcomeMotion extends StatefulWidget {
  const WelcomeMotion({super.key});
  @override
  State<WelcomeMotion> createState() => _WelcomeMotionState();
}

class _WelcomeMotionState extends State<WelcomeMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else {
      _motion.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: _motion,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF713126), Color(0xFF321A17), Color(0xFF21100F)],
          ),
        ),
        child: CustomPaint(painter: TemplePatternPainter()),
      ),
      builder: (_, child) => Transform.scale(
        scale: 1.02 + .035 * Curves.easeInOut.transform(_motion.value),
        child: child,
      ),
    ),
  );
}

/// Kolam-inspired brass linework, drawn locally at every screen resolution.
class TemplePatternPainter extends CustomPainter {
  const TemplePatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .43);
    final radius = size.width * .39;
    final brass = Paint()
      ..color = const Color(0xFFE6B85C).withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (final scale in [.78, .84, 1.0, 1.08]) {
      canvas.drawCircle(Offset.zero, radius * scale, brass);
    }
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 6);
      final petal = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -radius * .45,
          -radius * .4,
          -radius * .24,
          -radius * .78,
          0,
          -radius,
        )
        ..cubicTo(
          radius * .24,
          -radius * .78,
          radius * .45,
          -radius * .4,
          0,
          0,
        );
      canvas.drawPath(petal, brass);
      canvas.drawCircle(
        Offset(0, -radius * 1.16),
        3,
        Paint()..color = const Color(0xFFE6B85C).withValues(alpha: .5),
      );
      canvas.restore();
    }
    canvas.restore();
    // A restrained repeating dot border evokes hand-drawn threshold kolams.
    final dots = Paint()
      ..color = const Color(0xFFE6B85C).withValues(alpha: .15);
    for (double y = 32; y < size.height; y += 30) {
      canvas.drawCircle(Offset(17, y), 1.5, dots);
      canvas.drawCircle(Offset(size.width - 17, y), 1.5, dots);
    }
  }

  @override
  bool shouldRepaint(TemplePatternPainter oldDelegate) => false;
}
