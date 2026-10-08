import 'bronze_theme.dart';
import 'approved_opening.dart';

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
    duration: const Duration(milliseconds: 4200),
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
      backgroundColor: BronzePalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final art = const Interval(
                  0,
                  .72,
                  curve: Curves.easeOutCubic,
                ).transform(_animation.value);
                final title = const Interval(
                  .25,
                  .85,
                  curve: Curves.easeOutCubic,
                ).transform(_animation.value);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: title,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - title)),
                          child: const Text(
                            'Jyotara',
                            style: TextStyle(
                              fontFamily: 'JyotaraEditorial',
                              fontSize: 38,
                              letterSpacing: 1.5,
                              color: BronzePalette.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Opacity(
                        opacity: art,
                        child: Transform.scale(
                          scale: .92 + .08 * art,
                          child: GoldenSunriseMark(progress: _animation.value),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: title,
                        child: const Text(
                          'Ancient wisdom for a brighter you',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'JyotaraEditorial',
                            fontSize: 18,
                            color: BronzePalette.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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
            colors: [BronzePalette.raised, BronzePalette.background, BronzePalette.background],
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
  const TemplePatternPainter({this.intensity = 1});
  final double intensity;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .43);
    final radius = size.width * .39;
    final brass = Paint()
      ..color = BronzePalette.gold.withValues(alpha: .3 * intensity)
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
        Paint()
          ..color = BronzePalette.gold.withValues(alpha: .5 * intensity),
      );
      canvas.restore();
    }
    canvas.restore();
    // A restrained repeating dot border evokes hand-drawn threshold kolams.
    final dots = Paint()
      ..color = BronzePalette.gold.withValues(alpha: .15 * intensity);
    for (double y = 32; y < size.height; y += 30) {
      canvas.drawCircle(Offset(17, y), 1.5, dots);
      canvas.drawCircle(Offset(size.width - 17, y), 1.5, dots);
    }
  }

  @override
  bool shouldRepaint(TemplePatternPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}

/// One-shot reveal: no repeating work on reading surfaces, and no state reset.
class EntranceReveal extends StatelessWidget {
  const EntranceReveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Tactile visual feedback; pointer observation leaves the child's tap semantics intact.
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child});
  final Widget child;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;
  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .975 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

/// Fixed decorative depth without an idle animation loop or input interception.
class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({
    super.key,
    required this.child,
    this.showPattern = true,
  });
  final bool showPattern;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [BronzePalette.background, BronzePalette.background],
            stops: [0, .78],
          ),
        ),
      ),
      if (showPattern)
        const Positioned(
          top: -145,
          right: -110,
          width: 350,
          height: 350,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: TemplePatternPainter(intensity: .08),
                ),
              ),
            ),
          ),
        ),
      child,
    ],
  );
}

/// Fine orbital ornament for the approved editorial home card.
class HomeOrbitPainter extends CustomPainter {
  const HomeOrbitPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .88, size.height * .68);
    final p = Paint()
      ..color = BronzePalette.gold.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    for (final radius in [22.0, 31.0, 42.0]) {
      canvas.drawCircle(c, radius, p);
    }
    final star = Path()
      ..moveTo(c.dx, c.dy - 13)
      ..quadraticBezierTo(c.dx + 2, c.dy - 2, c.dx + 13, c.dy)
      ..quadraticBezierTo(c.dx + 2, c.dy + 2, c.dx, c.dy + 13)
      ..quadraticBezierTo(c.dx - 2, c.dy + 2, c.dx - 13, c.dy)
      ..quadraticBezierTo(c.dx - 2, c.dy - 2, c.dx, c.dy - 13);
    canvas.drawPath(star, p);
    p.style = PaintingStyle.fill;
    canvas.drawCircle(c.translate(31, 0), 3, p);
    canvas.drawCircle(c.translate(-28, 31), 4, p);
    canvas.drawCircle(c.translate(0, -42), 2, p);
  }

  @override
  bool shouldRepaint(HomeOrbitPainter old) => false;
}

/// Short, quiet page motion; Android's reduced-motion preference takes priority.
class MidnightPageTransitions extends PageTransitionsBuilder {
  const MidnightPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.025, .015),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}
