import 'bronze_theme.dart';
import 'jyotara_typography.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

const onboardingInk = BronzePalette.ink;
const onboardingMuted = BronzePalette.muted;
const onboardingGold = BronzePalette.gold;
const onboardingGreen = BronzePalette.background;

TextStyle onboardingHeading(double size) => TextStyle(
  fontFamily: 'JyotaraEditorial',
  fontFamilyFallback: JyotaraFonts.fallback,
  fontSize: size,
  height: 1.35,
  fontWeight: FontWeight.w500,
  color: onboardingInk,
);

/// Onboarding uses the same approved Bronze Eclipse palette as the app.
class OnboardingTheme extends StatelessWidget {
  const OnboardingTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: onboardingGreen,
        colorScheme: const ColorScheme.dark(
          primary: onboardingGold,
          onPrimary: BronzePalette.onAccent,
          surface: onboardingGreen,
          onSurface: onboardingInk,
          error: Color(0xFFFFB4AB),
        ),
        textTheme: base.textTheme.apply(
          fontFamily: 'JyotaraSans',
          fontFamilyFallback: JyotaraFonts.fallback,
          bodyColor: onboardingInk,
          displayColor: onboardingInk,
        ),
        checkboxTheme: CheckboxThemeData(
          side: const BorderSide(color: onboardingMuted),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          visualDensity: VisualDensity.compact,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: onboardingGold,
            textStyle: const TextStyle(
              fontFamily: JyotaraFonts.app,
              fontFamilyFallback: JyotaraFonts.fallback,
              fontSize: 13,
            ),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'JyotaraSans',
          fontFamilyFallback: JyotaraFonts.fallback,
          fontSize: 14,
          height: 1.45,
          color: onboardingInk,
        ),
        child: child,
      ),
    );
  }
}

class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({
    super.key,
    this.orbit = true,
    this.artOpacity = .48,
  });
  final bool orbit;
  final double artOpacity;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: artOpacity,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              .2126,
              .7152,
              .0722,
              0,
              0,
              .1807,
              .6079,
              .0614,
              0,
              0,
              .1276,
              .4291,
              .0433,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Image.asset(
              'assets/images/onboarding_mountains119.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x221C1512), Color(0x001C1512), Color(0x331C1512)],
            ),
          ),
        ),
        if (orbit) CustomPaint(painter: _OnboardingOrbits()),
      ],
    ),
  );
}

class _OnboardingOrbits extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = onboardingGold.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .99, -size.width * .18),
        radius: size.width * .44,
      ),
      0,
      math.pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The approved Zodiac J occupies the existing onboarding logo slots.
class OnboardingLogo extends StatefulWidget {
  const OnboardingLogo({super.key, this.size = 150, this.sunOnly = false});
  final double size;
  final bool sunOnly;
  @override
  State<OnboardingLogo> createState() => _OnboardingLogoState();
}

class _OnboardingLogoState extends State<OnboardingLogo> {
  ui.Image? _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await rootBundle.load('assets/images/jyotara-zodiac-j140.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Jyotara Zodiac J logo',
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: _LogoPainter(_image, widget.sunOnly)),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.image, this.sunOnly);
  final ui.Image? image;
  final bool sunOnly;
  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    final src = Rect.fromLTWH(
      0,
      0,
      image!.width.toDouble(),
      image!.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.contain, src.size, size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawImageRect(
      image!,
      src,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
    for (final horizontal in [true, false]) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
            end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: const [0, .16, .84, 1],
          ).createShader(destination),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.image != image || old.sunOnly != sunOnly;
}

class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: size + 36,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, .25, .75, 1],
            ).createShader(rect),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x99FFFFFF),
                  Color(0x99FFFFFF),
                  Colors.transparent,
                ],
                stops: [0, .32, .65, 1],
              ).createShader(rect),
              child: Image.asset(
                'assets/images/onboarding_mountains119.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        CustomPaint(size: Size(size + 76, size + 76), painter: _HeroOrbit()),
        Positioned(top: 0, child: OnboardingLogo(size: size)),
      ],
    ),
  );
}

class _HeroOrbit extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 18),
        radius = size.width * .49;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = onboardingGold.withValues(alpha: .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5,
    );
    for (final angle in [0.0, math.pi, math.pi * 1.28]) {
      canvas.drawCircle(
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        1.6,
        Paint()..color = onboardingGold.withValues(alpha: .35),
      );
    }
  }

  @override
  bool shouldRepaint(_HeroOrbit old) => false;
}

class OnboardingGlass extends StatelessWidget {
  const OnboardingGlass({
    super.key,
    required this.child,
    this.selected = false,
  });
  final Widget child;
  final bool selected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? [BronzePalette.raised, BronzePalette.raised]
            : [BronzePalette.raised, BronzePalette.card],
      ),
      border: Border.all(
        color: selected ? onboardingGold : BronzePalette.border,
        width: selected ? 1 : .7,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x20000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

InputDecoration onboardingInput({
  String? hint,
  String? label,
  Widget? prefix,
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  labelText: label,
  hintStyle: const TextStyle(
    fontFamily: 'JyotaraSans',
    color: onboardingMuted,
    fontSize: 14,
  ),
  labelStyle: const TextStyle(color: onboardingMuted),
  prefixIcon: prefix,
  suffixIcon: suffix,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  counterText: '',
);

class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.busy = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [BronzePalette.accent, BronzePalette.accent],
      ),
      border: Border.all(color: const Color(0x60FFF0C9)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x25000000),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: BronzePalette.onAccent,
        disabledForegroundColor: const Color(0xFF40351F),
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JyotaraEditorial',
                fontFamilyFallback: JyotaraFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 21,
                height: 1.35,
              ),
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: BronzePalette.onAccent,
              ),
            )
          else
            const Icon(Icons.arrow_forward, size: 20),
        ],
      ),
    ),
  );
}
