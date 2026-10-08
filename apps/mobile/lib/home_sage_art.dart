import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bronze_theme.dart';

const approvedSageAsset = 'assets/images/home-sage140.png';

/// The approved portrait stays intact. Warm lamp glow, slow parallax and fine
/// drifting dust add motion; edge masks merge the scene into the Ask card.
class HomeSageArt extends StatefulWidget {
  const HomeSageArt({super.key});

  @override
  State<HomeSageArt> createState() => _HomeSageArtState();
}

class _HomeSageArtState extends State<HomeSageArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating && !_motion.isCompleted) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipRect(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, .28, .73, 1],
            ).createShader(bounds),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, .62, 1],
              ).createShader(bounds),
              child: AnimatedBuilder(
                animation: _motion,
                child: Image.asset(
                  approvedSageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
                builder: (context, portrait) {
                  final breathing =
                      (1 - math.cos(_motion.value * math.pi * 2)) / 2;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: 1 + .018 * breathing,
                        alignment: Alignment.bottomCenter,
                        child: portrait,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-.55, -.1),
                            radius: .7,
                            colors: [
                              BronzePalette.gold.withValues(
                                alpha: .045 + .04 * breathing,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      CustomPaint(painter: _LampDust(_motion.value)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LampDust extends CustomPainter {
  const _LampDust(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 9; i++) {
      final phase = (progress + i * .137) % 1;
      final opacity = math.sin(phase * math.pi) * .28;
      final point = Offset(
        size.width * (.06 + (i % 3) * .06) +
            math.sin(phase * math.pi * 2 + i) * 3,
        size.height * (.85 - phase * .66),
      );
      canvas.drawCircle(
        point,
        i.isEven ? 1.1 : .7,
        Paint()..color = BronzePalette.gold.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_LampDust oldDelegate) => progress != oldDelegate.progress;
}
