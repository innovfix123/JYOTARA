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
      backgroundColor: const Color(0xFF090612),
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
                          colors: [Color(0xFF9B79FF), Color(0xFF5A37A2)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B79FF)
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
                        color: Color(0xFFE0D5FF),
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
      child: Image.asset(
        'assets/images/cosmic-onboarding.png',
        fit: BoxFit.cover,
      ),
      builder: (_, child) => Transform.scale(
        scale: 1.02 + .035 * Curves.easeInOut.transform(_motion.value),
        child: child,
      ),
    ),
  );
}
