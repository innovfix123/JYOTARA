import 'package:flutter/material.dart';

import 'bronze_theme.dart';

const matchingSceneAssets = {
  'My Crush': 'assets/images/matching-crush139.png',
  'My Partner': 'assets/images/matching-partner139.png',
  'My Friend': 'assets/images/matching-friend139.png',
  'Marriage': 'assets/images/matching-marriage139.png',
};

/// Exact approved scene; ellipse and vertical masks blend all four edges.
class MatchingSceneArt extends StatelessWidget {
  const MatchingSceneArt({super.key, required this.type, this.height = 190});
  final String type;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      // Cover the sub-pixel mask seam seen on Samsung's GPU. The artwork
      // and approved edge gradients stay unchanged inside this one-pixel rim.
      decoration: BoxDecoration(
        border: Border.all(color: BronzePalette.background, width: 1),
      ),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const RadialGradient(
          center: Alignment(0, -.18),
          radius: .5,
          colors: [
            Colors.white,
            Colors.white,
            Color(0xAAFFFFFF),
            Color(0x44FFFFFF),
            Colors.transparent,
          ],
          stops: [.34, .52, .71, .86, 1],
          transform: _SceneEllipse(),
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Color(0xBBFFFFFF),
              Colors.white,
              Colors.white,
              Color(0xAAFFFFFF),
              Colors.transparent,
            ],
            stops: [0, .12, .25, .6, .76, 1],
          ).createShader(bounds),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              BronzePalette.background,
              BlendMode.screen,
            ),
            child: Image.asset(
              matchingSceneAssets[type]!,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -.4),
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SceneEllipse extends GradientTransform {
  const _SceneEllipse();
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final center = Offset(bounds.width * .5, bounds.height * .41);
    // RadialGradient radius is relative to the shorter side.
    final sx = bounds.width / bounds.shortestSide;
    final sy = bounds.height * 1.82 / bounds.shortestSide;
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}

const loveLetterAsset = 'assets/images/matching-love-letter138.png';

/// The selected Love Letter master artwork, with the preview's edge fade.
class LoveLetterArt extends StatelessWidget {
  const LoveLetterArt({super.key, this.height, this.square = false});
  final double? height;
  final bool square;
  @override
  Widget build(BuildContext context) {
    final image = ColorFiltered(
      colorFilter: const ColorFilter.mode(
        BronzePalette.background,
        BlendMode.screen,
      ),
      child: Image.asset(
        loveLetterAsset,
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0),
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        width: double.infinity,
        height: double.infinity,
      ),
    );
    return SizedBox(
      height: height,
      child: square
          ? image
          : ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, .1, .78, 1],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0, .13, .87, 1],
                ).createShader(bounds),
                child: image,
              ),
            ),
    );
  }
}
