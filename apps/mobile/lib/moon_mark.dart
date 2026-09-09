import 'package:flutter/material.dart';

/// Jyotara's pointed lunar crescent, companion star and fine celestial rim.
class MoonMark extends StatelessWidget {
  const MoonMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Jyotara moon',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _MoonPainter()),
    ),
  );
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final rim = Paint()
      ..color = const Color(0xFFF7E8CA).withValues(alpha: .48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(const Offset(50, 50), 44, rim);
    final moon = Path()
      ..moveTo(67, 18)
      ..cubicTo(35, 8, 12, 32, 20, 60)
      ..cubicTo(28, 89, 62, 96, 82, 72)
      ..cubicTo(57, 84, 31, 64, 38, 40)
      ..cubicTo(42, 26, 55, 20, 67, 18)
      ..close();
    canvas.drawPath(
      moon,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCED), Color(0xFFF8DE9C), Color(0xFFEABD60)],
        ).createShader(const Rect.fromLTWH(15, 15, 70, 75)),
    );
    final star = Path()
      ..moveTo(69, 29)
      ..lineTo(72, 39)
      ..lineTo(82, 42)
      ..lineTo(72, 45)
      ..lineTo(69, 55)
      ..lineTo(66, 45)
      ..lineTo(56, 42)
      ..lineTo(66, 39)
      ..close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF8DE));
    canvas.drawCircle(
      const Offset(82, 25),
      1.8,
      Paint()..color = const Color(0xFFFFF8DE),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => false;
}
