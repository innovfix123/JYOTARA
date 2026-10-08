import 'bronze_theme.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// High-resolution welcome artwork spans the screen while controls retain safe insets.
class WelcomeSunArtwork extends StatelessWidget {
  const WelcomeSunArtwork({super.key});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(0.0, 480.0);
    return ExcludeSemantics(
      child: SizedBox(
        height: width * 2 / 3,
        child: OverflowBox(
          minWidth: width,
          maxWidth: width,
          child: SizedBox(
            width: width,
            height: width * 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/welcome_sun_gold_hd.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          BronzePalette.background,
                          Color(0x001C1512),
                          Color(0x001C1512),
                          BronzePalette.background,
                        ],
                        stops: [0, .22, .73, 1],
                      ),
                    ),
                  ),
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          BronzePalette.background,
                          Color(0x001C1512),
                          Color(0x001C1512),
                          BronzePalette.background,
                        ],
                        stops: [0, .16, .84, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeHeading extends StatelessWidget {
  const WelcomeHeading({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Text(
        'Jyotara',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'JyotaraEditorial',
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: BronzePalette.ink,
        ),
      ),
      SizedBox(height: 24),
      Text(
        'Ancient wisdom\nfor a brighter you',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'JyotaraEditorial',
          fontSize: 22,
          height: 1.3,
          color: BronzePalette.ink,
        ),
      ),
      SizedBox(height: 16),
      WelcomeSunArtwork(),
    ],
  );
}

/// A staggered, single entrance rather than distracting endless motion.
class WelcomeEntrance extends StatelessWidget {
  const WelcomeEntrance({super.key, required this.child, this.delay = 0});
  final Widget child;
  final double delay;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        final progress = Interval(
          delay,
          1,
          curve: Curves.easeOutCubic,
        ).transform(value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Post-registration welcome has its own cinematic entrance, separate from OTP.
class AnimatedWelcomePage extends StatefulWidget {
  const AnimatedWelcomePage({super.key, required this.onEnter});
  final VoidCallback onEnter;
  @override
  State<AnimatedWelcomePage> createState() => _AnimatedWelcomePageState();
}

class _AnimatedWelcomePageState extends State<AnimatedWelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.stop();
      _reveal.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Widget _stage(double progress, Widget child, {double rise = 18}) => Opacity(
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, rise * (1 - progress)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BronzePalette.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) {
                final t = _reveal.value;
                final brand = const Interval(
                  0,
                  .3,
                  curve: Curves.easeOut,
                ).transform(t);
                final sun = const Interval(
                  .08,
                  .74,
                  curve: Curves.easeOutCubic,
                ).transform(t);
                final words = const Interval(
                  .38,
                  .86,
                  curve: Curves.easeOutCubic,
                ).transform(t);
                final action = const Interval(
                  .57,
                  1,
                  curve: Curves.easeOutCubic,
                ).transform(t);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    _stage(
                      brand,
                      const Text(
                        'Jyotara',
                        style: TextStyle(
                          fontFamily: 'JyotaraEditorial',
                          fontSize: 29,
                          color: BronzePalette.ink,
                        ),
                      ),
                      rise: 8,
                    ),
                    const SizedBox(height: 12),
                    _stage(
                      brand,
                      const Text(
                        'A MOMENT FOR YOU',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 3,
                          color: BronzePalette.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ClipRect(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: sun,
                            child: Transform.scale(
                              scale: .76 + .24 * sun,
                              child: const WelcomeSunArtwork(),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _WelcomeLightPainter(t),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          _stage(
                            words,
                            const Text(
                              'Welcome to\nJyotara',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'JyotaraEditorial',
                                fontSize: 36,
                                height: 1.12,
                                color: BronzePalette.ink,
                              ),
                            ),
                            rise: 24,
                          ),
                          const SizedBox(height: 18),
                          _stage(
                            words,
                            const Text(
                              'Your journey begins with a little clarity.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: BronzePalette.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _stage(
                            action,
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const Key('enterApp'),
                                onPressed: widget.onEnter,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Explore Jyotara',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _stage(
                            action,
                            const Text(
                              'Ancient wisdom for a brighter you',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'JyotaraEditorial',
                                fontSize: 13,
                                color: BronzePalette.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeLightPainter extends CustomPainter {
  const _WelcomeLightPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(progress * math.pi);
    final center = Offset(size.width / 2, size.height * .43);
    final radius = size.width * (.22 + progress * .1);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          BronzePalette.gold.withValues(alpha: .12 * wave),
          const Color(0x00ECC38C),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
    final ray = Paint()
      ..color = const Color(0xFFF1D49A).withValues(alpha: .55 * wave)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + .15 * progress;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final length = 2.0 + 3.0 * wave;
      canvas.drawLine(
        point - Offset(length, 0),
        point + Offset(length, 0),
        ray,
      );
      canvas.drawLine(
        point - Offset(0, length),
        point + Offset(0, length),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(_WelcomeLightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
