import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'bronze_theme.dart';
import 'rasi_emblem.dart';
import 'services/name_display.dart';
import 'services/ui_language.dart';

const cupidAsset = 'assets/images/matching-cupid139.png';
const matchingHeartAsset = 'assets/images/matching-heart139.png';
const matchingMotionDuration = Duration(milliseconds: 4900);

double _clamp(double p) => p.clamp(0.0, 1.0);
double _range(double t, double a, double b) => _clamp((t - a) / (b - a));
double _ease(double p) => 1 - math.pow(1 - p, 3).toDouble();
double _smooth(double p) => p * p * (3 - 2 * p);
double _mix(double a, double b, double p) => a + (b - a) * p;

/// Native port of the approved motion.js clock and camera choreography.
class MatchingMotionFrame {
  MatchingMotionFrame(this.t, this.size) {
    final w = size.width, h = size.height;
    entrance = _ease(_range(t, 0, 520));
    pull = _smooth(_range(t, 520, 1700));
    fired = _range(t, 1710, 1810);
    flight = t < 1980
        ? .5 * _smooth(_range(t, 1750, 1980))
        : t < 2390
        ? .5 + .31 * _range(t, 1980, 2390)
        : .81 + .19 * _smooth(_range(t, 2390, 2600));
    hit = _range(t, 2600, 3150);
    join = _ease(_range(t, 3240, 4350));
    exit = _ease(_range(t, 3200, 3990));
    impactTime = math.max(0, t - 2600);
    shock = t < 2600
        ? 0
        : math.sin(impactTime / 48) * math.exp(-impactTime / 270);
    wing = math.sin(t / 96) * 6.5 * (1 - exit);
    cx = _mix(-46, 0, entrance) - pull * 7 - fired * 4 - exit * 65;
    cy = _mix(24, 0, entrance) + math.sin(t / 210) * 2.4 + exit * 7;
    cupidAngle = _mix(-9, -2, entrance) - pull * 3 + fired * 4 - exit * 9;
    target = Offset(
      _mix(w * 1.05, w * .39, join),
      _mix(h * .2 + w * .2, h * .2 + w * .24, join),
    );
    second = Offset(
      _mix(w * .2, w * .67, join),
      _mix(h * .72, h * .25 + w * .215, join),
    );
    targetScale =
        1 +
        (t < 2600
            ? 0
            : math.sin(impactTime / 76) * math.exp(-impactTime / 390) * .14) +
        join * .2;
    targetAngle = _mix(-8, -16, join) + shock * 4;
    start = Offset(w * .525 + cx * .4, h * .22 + w * .55 * .315 - 3);
    end = Offset(w * 1.05, h * .2 + w * .2 - 4);
    arrow = t < 2600 ? point(flight) : target - const Offset(0, 4);
    arrowAngle = t < 2600
        ? math.atan2(
            end.dy - start.dy - math.cos(flight * math.pi) * math.pi * h * .045,
            end.dx - start.dx,
          )
        : targetAngle * .15 * math.pi / 180;
    final close = _ease(_range(t, 520, 1320));
    final follow = _smooth(_range(t, 1750, 2060));
    final settle = _ease(_range(t, 2600, 2840));
    var cameraZoom = _mix(.72, 2.08, close);
    var lookX = _mix(w * .58, w * .39, close);
    var lookY = _mix(h * .45, h * .43, close);
    cameraZoom = _mix(cameraZoom, 1.6, follow) + settle * .12;
    lookX = _mix(lookX, arrow.dx + w * .035 * (1 - settle), follow);
    lookY = _mix(lookY, arrow.dy, follow);
    zoom = _mix(cameraZoom, 1, join);
    lookX = _mix(lookX, w * .5, join);
    lookY = _mix(lookY, h * .45, join);
    camera = Offset(
      w * .5 - lookX * zoom - shock * 1.3,
      h * .45 - lookY * zoom + shock * .7,
    );
  }
  final double t;
  final Size size;
  late final double entrance,
      pull,
      fired,
      flight,
      hit,
      join,
      exit,
      impactTime,
      shock,
      wing,
      cx,
      cy,
      cupidAngle,
      targetScale,
      targetAngle,
      zoom,
      arrowAngle;
  late final Offset target, second, start, end, arrow, camera;
  Offset point(double p) => Offset(
    _mix(start.dx, end.dx, p),
    _mix(start.dy, end.dy, p) - math.sin(p * math.pi) * size.height * .045,
  );
  String get phase => t < 520
      ? 'wide'
      : t < 1750
      ? 'bow-close-up'
      : t < 2600
      ? 'arrow-follow'
      : t < 3240
      ? 'heart-impact'
      : 'pair-reveal';
}

class CinematicMatchingAnimation extends StatefulWidget {
  const CinematicMatchingAnimation({
    super.key,
    required this.first,
    required this.second,
    required this.type,
    this.firstRasi = -1,
    this.secondRasi = -1,
    this.resultReady = true,
  });
  final String first, second, type;
  final int firstRasi, secondRasi;
  final bool resultReady;
  @override
  State<CinematicMatchingAnimation> createState() =>
      _CinematicMatchingAnimationState();
}

class _CinematicMatchingAnimationState extends State<CinematicMatchingAnimation>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: matchingMotionDuration,
  );
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _cupid;
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) {
      _stream = const AssetImage(cupidAsset)
          .resolve(createLocalImageConfiguration(context));
      _listener = ImageStreamListener((image, _) {
        if (mounted) setState(() => _cupid = image.image);
      });
      _stream!.addListener(_listener!);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 1;
    } else if (!started) {
      started = true;
      motion.forward();
    }
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tamil =
        context
            .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
            ?.notifier
            ?.value ==
        'ta';
    String tr(String en, String ta) => tamil ? ta : en;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          final t = motion.value * matchingMotionDuration.inMilliseconds;
          return Column(
            children: [
              Text(
                uiText(context, widget.type).toUpperCase(),
                style: const TextStyle(
                  color: BronzePalette.gold,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr(
                  'A little spark between you',
                  'உங்களுக்குள் ஒரு சிறு ஈர்ப்பு',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'JyotaraEditorial',
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  color: BronzePalette.ink,
                ),
              ),
              LayoutBuilder(
                builder: (context, bounds) {
                  final size = Size(bounds.maxWidth, bounds.maxWidth / 1.12);
                  final f = MatchingMotionFrame(t, size);
                  final heartSize = size.width * .4;
                  return Semantics(
                    label: tr(
                      'Cupid brings two hearts together',
                      'இரு இதயங்கள் இணைகின்றன',
                    ),
                    child: SizedBox.fromSize(
                      size: size,
                      child: ClipRect(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(.44, -.12),
                                    radius: .75,
                                    colors: [
                                      BronzePalette.rose.withValues(
                                        alpha:
                                            .08 +
                                            (t >= 2600
                                                ? math.exp(
                                                        -f.impactTime / 530,
                                                      ) *
                                                      .08
                                                : 0),
                                      ),
                                      BronzePalette.background,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Transform(
                              transform: Matrix4.identity()
                                ..translateByDouble(
                                  f.camera.dx,
                                  f.camera.dy,
                                  0,
                                  1,
                                )
                                ..scaleByDouble(f.zoom, f.zoom, 1, 1),
                              child: SizedBox(
                                width: size.width,
                                height: size.height,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _CupidPainter(f, _cupid),
                                      ),
                                    ),
                                    Positioned(
                                      left: f.target.dx - heartSize / 2,
                                      top: f.target.dy - heartSize / 2,
                                      width: heartSize,
                                      height: heartSize,
                                      child: Opacity(
                                        opacity: _ease(_range(t, 150, 700)),
                                        child: Transform.scale(
                                          scale: f.targetScale,
                                          child: Transform.rotate(
                                            angle:
                                                f.targetAngle * math.pi / 180,
                                            child: Hero(
                                              tag: 'matching-heart-front',
                                              child: Image.asset(
                                                matchingHeartAsset,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: f.second.dx - size.width * .215,
                                      top: f.second.dy - size.width * .215,
                                      width: size.width * .43,
                                      height: size.width * .43,
                                      child: Opacity(
                                        opacity: _smooth(_range(t, 3260, 3920)),
                                        child: Transform.scale(
                                          scale: _mix(.55, 1, f.join),
                                          child: Transform.rotate(
                                            angle:
                                                _mix(-35, 13, f.join) *
                                                math.pi /
                                                180,
                                            child: Hero(
                                              tag: 'matching-heart-back',
                                              child: Image.asset(
                                                matchingHeartAsset,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _CupidEffects(f),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        BronzePalette.background,
                                        BronzePalette.background.withValues(
                                          alpha: 0,
                                        ),
                                        BronzePalette.background.withValues(
                                          alpha: 0,
                                        ),
                                        BronzePalette.background,
                                      ],
                                      stops: const [0, .14, .83, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: const Alignment(0, -.1),
                                      radius: .7,
                                      colors: [
                                        Colors.transparent,
                                        BronzePalette.background.withValues(
                                          alpha: .3,
                                        ),
                                        BronzePalette.background,
                                      ],
                                      stops: const [.32, .75, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: size.height * .03,
                              child: Opacity(
                                opacity: _smooth(_range(t, 4350, 4740)),
                                child: Text(
                                  tr(
                                    widget.resultReady
                                        ? 'Your connection is ready'
                                        : 'Comparing your charts…',
                                    widget.resultReady
                                        ? 'உங்கள் இணைப்பு தயாராக உள்ளது'
                                        : 'உங்கள் ஜாதகங்களை ஒப்பிடுகிறோம்…',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'JyotaraEditorial',
                                    fontSize: 24,
                                    color: BronzePalette.gold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final p in [
                    (widget.first, widget.firstRasi),
                    (widget.second, widget.secondRasi),
                  ])
                    Expanded(
                      child: Column(
                        children: [
                          RasiEmblem(index: p.$2, size: 54),
                          const SizedBox(height: 5),
                          Text(
                            tamil ? tamilDisplayName(p.$1) : p.$1,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BronzePalette.ink,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: 1 - _smooth(_range(t, 4350, 4720)),
                child: Text(
                  t < 1750
                      ? tr('A little spark…', 'ஒரு சிறு ஈர்ப்பு…')
                      : t < 3240
                      ? tr(
                          'Bringing you together…',
                          'உங்கள் இணைப்பை அறிகிறோம்…',
                        )
                      : tr(
                          'Your connection is ready',
                          'உங்கள் இணைப்பு தயாராக உள்ளது',
                        ),
                  style: const TextStyle(
                    color: BronzePalette.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MatchingHeartsArt extends StatelessWidget {
  const MatchingHeartsArt({super.key, this.height = 182});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (context, b) => Stack(
        children: [
          Positioned(
            left: b.maxWidth * .15,
            top: -6,
            width: b.maxWidth * .48,
            height: height,
            child: Transform.rotate(
              angle: -16 * math.pi / 180,
              child: Hero(
                tag: 'matching-heart-front',
                child: Image.asset(
                  matchingHeartAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned(
            right: b.maxWidth * .11,
            top: 8,
            width: b.maxWidth * .43,
            height: height,
            child: Transform.rotate(
              angle: 13 * math.pi / 180,
              child: Hero(
                tag: 'matching-heart-back',
                child: Image.asset(
                  matchingHeartAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CupidPainter extends CustomPainter {
  const _CupidPainter(this.f, this.image);
  final MatchingMotionFrame f;
  final ui.Image? image;
  @override
  void paint(Canvas c, Size size) {
    if (image == null) return;
    final side = size.width * .55;
    c.save();
    c.translate(
      -size.width * .01 + f.cx + side / 2,
      size.height * .22 + f.cy + side / 2,
    );
    c.rotate(f.cupidAngle * math.pi / 180);
    final scale = _mix(.86, 1, f.entrance);
    c.scale(scale);
    c.translate(-side / 2, -side / 2);
    final opacity = f.entrance * (1 - f.exit);
    final release = _smooth(f.fired);
    for (var i = 0; i < 2; i++) {
      final alpha = opacity * (i == 0 ? 1 - release : release);
      if (alpha < .001) continue;
      final src = Rect.fromLTWH(
        i * image!.width / 2,
        0,
        image!.width / 2,
        image!.height.toDouble(),
      );
      final dest = Rect.fromLTWH(0, 0, side, side);
      final p = Paint()
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withValues(alpha: alpha);
      Path path(List<Offset> vertices) => Path()
        ..addPolygon(
          vertices
              .map((o) => Offset(o.dx * side / 100, o.dy * side / 100))
              .toList(),
          true,
        );
      c.save();
      c.clipPath(
        path(const [
          Offset(44, 0),
          Offset(100, 0),
          Offset(100, 100),
          Offset(0, 100),
          Offset(0, 46),
          Offset(25, 46),
          Offset(34, 42),
          Offset(34, 37),
          Offset(27, 35),
          Offset(26, 29),
          Offset(31, 27),
          Offset(39, 29),
          Offset(44, 26),
        ]),
      );
      c.drawImageRect(image!, src, dest, p);
      c.restore();
      c.save();
      c.translate(side * .35, side * .32);
      c.rotate(f.wing * .6 * math.pi / 180);
      c.scale(
        math.cos((f.wing * 2.3 + (i == 1 ? 2 : 0)) * math.pi / 180) *
            (1 - f.wing.abs() / 220),
        1,
      );
      c.translate(-side * .35, -side * .32);
      c.clipPath(
        path(const [
          Offset(7, 7),
          Offset(27, 11),
          Offset(40, 22),
          Offset(42, 32),
          Offset(39, 41),
          Offset(33, 49),
          Offset(26, 46),
          Offset(21, 38),
          Offset(17, 29),
          Offset(11, 24),
        ]),
      );
      c.drawImageRect(image!, src, dest, p);
      c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_CupidPainter old) => old.f.t != f.t || old.image != image;
}

class _CupidEffects extends CustomPainter {
  const _CupidEffects(this.f);
  final MatchingMotionFrame f;
  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height, t = f.t;
    final p = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 36; i++) {
      final a = (.18 + math.sin(t / 350 + i) * .1) * (1 - f.join * .6);
      p.color = (i % 3 != 0 ? BronzePalette.gold : BronzePalette.rose)
          .withValues(alpha: a);
      c.drawCircle(
        Offset(
          w * (.08 + ((i * 37) % 132) / 100),
          h * (.13 + ((i * 23) % 61) / 100) + math.sin(t / 600 + i) * 5,
        ),
        i % 4 == 0 ? 1.4 : .7,
        p,
      );
    }
    if (t >= 640 && t < 1750) {
      final hand = Offset(
        w * .55 * .51 + f.cx,
        h * .22 + w * .55 * .315 + f.cy,
      );
      final ends = [
        Offset(w * .55 * .76 + f.cx, h * .22 + w * .55 * .023 + f.cy),
        Offset(w * .55 * .85 + f.cx, h * .22 + w * .55 * .64 + f.cy),
      ];
      final sheen = _range(t, 640, 1690);
      for (var i = 0; i < 2; i++) {
        p.color = BronzePalette.ink.withValues(
          alpha: math.sin(sheen * math.pi) * .5,
        );
        c.drawCircle(
          Offset.lerp(ends[i], hand, i == 1 ? 1 - sheen : sheen)!,
          1.4,
          p,
        );
      }
    }
    if (t >= 1750 && t < 2910) {
      final fade = t < 2600 ? 1.0 : 1 - _range(t, 2600, 2910);
      for (var j = 1; j <= 48; j++) {
        final a = _clamp(f.flight - j * .009);
        p
          ..color = (j % 3 != 0 ? BronzePalette.gold : BronzePalette.ink)
              .withValues(alpha: fade * math.pow(1 - j / 49, 1.8) * .75)
          ..strokeWidth = _mix(.3, 2, 1 - j / 49);
        c.drawLine(f.point(a), f.point(_clamp(a - .018)), p);
      }
    }
    if (t >= 2600 && t < 3710) {
      final q = _range(t, 2600, 3550), spread = _ease(q);
      final fade = 1 - _smooth(_range(t, 2920, 3710));
      c.drawCircle(
        f.target,
        55 * (.4 + _ease(_range(t, 2600, 3160)) * 1.7),
        Paint()
          ..color = BronzePalette.gold.withValues(
            alpha: math.exp(-f.impactTime / 360) * .25,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
      for (var i = 0; i < 64; i++) {
        final a = i * 2.399963, r = (28 + (i * 17) % 85) * spread;
        p.color = (i % 4 != 0 ? BronzePalette.gold : BronzePalette.rose)
            .withValues(alpha: _clamp(fade * (.45 + ((i * 7) % 9) / 20)));
        c.save();
        c.translate(
          f.target.dx + math.cos(a) * r,
          f.target.dy + math.sin(a) * r * .75 + q * q * 15,
        );
        c.rotate(a);
        c.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: i % 5 == 0 ? 3.6 : 2,
            height: i % 5 == 0 ? 6 : 1.6,
          ),
          p,
        );
        c.restore();
      }
      for (var i = 0; i < 2; i++) {
        final q = _range(t, 2600 + i * 90, 3150 + i * 90), r = 25 + q * 78;
        c.drawOval(
          Rect.fromCenter(center: f.target, width: r * 2, height: r * 1.6),
          Paint()
            ..color = BronzePalette.gold.withValues(alpha: (1 - q) * .45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7,
        );
      }
    }
    if (t >= 3260 && t < 4770) {
      final fade = math.sin(_range(t, 3260, 4770) * math.pi) * .6;
      for (var i = 0; i < 28; i++) {
        final a = i * .12 + t / 540;
        p.color = BronzePalette.gold.withValues(alpha: fade * i / 28);
        c.drawCircle(
          Offset(
            w * .5 + math.cos(a) * w * .28,
            h * .37 + math.sin(a) * h * .18,
          ),
          i % 7 != 0 ? 1 : 1.8,
          p,
        );
      }
    }
    if (t >= 1750 && t < 3650) {
      final alpha = t < 2600 ? 1.0 : 1 - _smooth(_range(t, 3300, 3650));
      c.save();
      c.translate(f.arrow.dx, f.arrow.dy);
      c.rotate(f.arrowAngle);
      c.scale(t < 2600 ? 1 : 1 - f.hit * .06, 1);
      p
        ..color = BronzePalette.gold.withValues(alpha: alpha)
        ..strokeWidth = 2.5;
      c.drawLine(const Offset(-72, 0), Offset.zero, p);
      c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-11, -5)
          ..lineTo(-8, 0)
          ..lineTo(-11, 5)
          ..close(),
        p,
      );
      c.drawPath(
        Path()
          ..moveTo(-72, -5)
          ..lineTo(-58, 0)
          ..lineTo(-72, 5)
          ..lineTo(-67, 0)
          ..close(),
        p,
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_CupidEffects old) => old.f.t != f.t;
}
