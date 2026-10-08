import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_mark.dart';
import 'bronze_theme.dart';
import 'services/profile_avatar.dart';

/// Native rendering of the approved zodiac, Starlight, Orbit and Constellation.
class CelestialAvatar extends StatelessWidget {
  const CelestialAvatar({
    super.key,
    required this.avatar,
    this.rasiIndex = -1,
    this.size = 76,
  });
  final ProfileAvatar avatar;
  final int rasiIndex;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: BronzePalette.gold.withValues(alpha: .8)),
      gradient: RadialGradient(
        center: const Alignment(-.3, -.4),
        colors: [BronzePalette.raised, BronzePalette.card],
      ),
    ),
    child: ClipOval(
      child: avatar == ProfileAvatar.zodiac && rasiIndex >= 0 && rasiIndex < 12
          ? ColorFiltered(
              colorFilter: const ColorFilter.mode(
                BronzePalette.card,
                BlendMode.screen,
              ),
              child: HomeRasiArt(index: rasiIndex),
            )
          : CustomPaint(
              painter: _CelestialPainter(
                avatar == ProfileAvatar.zodiac
                    ? ProfileAvatar.constellation
                    : avatar,
              ),
            ),
    ),
  );
}

class _CelestialPainter extends CustomPainter {
  const _CelestialPainter(this.avatar);
  final ProfileAvatar avatar;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = size.center(Offset.zero);
    final line = Paint()
      ..color = BronzePalette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, side / 70);
    if (avatar == ProfileAvatar.constellation) {
      final points = [
        const Offset(.26, .30),
        const Offset(.53, .23),
        const Offset(.68, .53),
        const Offset(.40, .70),
      ].map((p) => Offset(p.dx * side, p.dy * side)).toList();
      final subtle = Paint()
        ..color = BronzePalette.gold.withValues(alpha: .5)
        ..strokeWidth = math.max(1.0, side / 90);
      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], subtle);
      }
      for (final p in points) {
        canvas.drawCircle(
          p,
          side * .065,
          Paint()
            ..color = BronzePalette.gold.withValues(alpha: .2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(p, side * .035, Paint()..color = BronzePalette.gold);
      }
    } else if (avatar == ProfileAvatar.orbit) {
      for (final angle in [0.0, math.pi / 3, math.pi * 2 / 3]) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: side * .63,
            height: side * .27,
          ),
          line,
        );
        canvas.restore();
      }
      canvas.drawCircle(
        center,
        side * .055,
        Paint()..color = BronzePalette.gold,
      );
      canvas.drawCircle(
        center + Offset(side * .30, 0),
        side * .035,
        Paint()..color = BronzePalette.gold,
      );
    } else {
      canvas.drawCircle(
        center,
        side * .34,
        line..color = BronzePalette.gold.withValues(alpha: .25),
      );
      line.color = BronzePalette.gold;
      for (final item in [
        (const Offset(.48, .55), .21),
        (const Offset(.72, .29), .105),
        (const Offset(.25, .28), .065),
      ]) {
        final c = Offset(side * item.$1.dx, side * item.$1.dy),
            r = side * item.$2;
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final radius = i.isEven ? r : r * .27;
          final angle = -math.pi / 2 + i * math.pi / 4;
          final p =
              c + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, line);
      }
    }
  }

  @override
  bool shouldRepaint(_CelestialPainter oldDelegate) =>
      oldDelegate.avatar != avatar;
}
