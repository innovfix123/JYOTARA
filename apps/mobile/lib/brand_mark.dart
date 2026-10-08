import 'bronze_theme.dart';

import 'package:flutter/material.dart';

/// Approved Zodiac J logo used in existing brand placements.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      'assets/images/jyotara-zodiac-j140.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'Jyotara',
    ),
  );
}

/// Each atlas cell contains one sign, ordered Aries through Pisces.
class RasiFigure extends StatelessWidget {
  const RasiFigure({
    super.key,
    required this.index,
    this.size = 58,
    this.goldStyle = false,
  });
  final int index;
  final bool goldStyle;
  final double size;
  @override
  Widget build(BuildContext context) {
    assert(index >= 0 && index < 12);
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned(
                left: -(index % 4) * size,
                top: -(index ~/ 4) * size,
                width: size * 4,
                height: size * 3,
                child: Image.asset(
                  goldStyle
                      ? 'assets/images/rasi_gold_figures.png'
                      : 'assets/images/rasi_figures.png',
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consistent square hero framing for every Rasi on Home.
/// The approved Pisces image remains the brightness/style reference.
class HomeRasiArt extends StatelessWidget {
  const HomeRasiArt({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    assert(index >= 0 && index < 12);
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1,
        child: index == 11
            ? Image.asset(
                'assets/images/home_meena_bright.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth;
                  return ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          left: -(index % 4) * size,
                          top: -(index ~/ 4) * size,
                          width: size * 4,
                          height: size * 3,
                          child: Image.asset(
                            'assets/images/home_rasi_bright_atlas.png',
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Existing Home art, small and still; black pixels blend into the app surface.
class BlendedRasiArt extends StatelessWidget {
  const BlendedRasiArt({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => const RadialGradient(
      colors: [Colors.white, Colors.white, Colors.transparent],
      stops: [0, .55, 1],
      radius: .72,
    ).createShader(bounds),
    child: ColorFiltered(
      colorFilter: const ColorFilter.mode(
        BronzePalette.background,
        BlendMode.screen,
      ),
      child: HomeRasiArt(index: index),
    ),
  );
}

class BlendedRasiArtWheel extends StatelessWidget {
  const BlendedRasiArtWheel({super.key});
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => const RadialGradient(
      colors: [Colors.white, Colors.white, Colors.transparent],
      stops: [0, .55, 1],
      radius: .72,
    ).createShader(bounds),
    child: ColorFiltered(
      colorFilter: const ColorFilter.mode(
        BronzePalette.background,
        BlendMode.screen,
      ),
      child: Image.asset(
        'assets/images/jyotara_rasi_logo.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}
