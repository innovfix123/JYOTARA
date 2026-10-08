import 'package:flutter/material.dart';

/// Exact colours from the approved Bronze Eclipse preview.
abstract final class BronzePalette {
  static const background = Color(0xFF1C1512);
  static const card = Color(0xFF30261E);
  static const raised = Color(0xFF49362A);
  static const ink = Color(0xFFFFF5E7);
  static const muted = Color(0xFFD3C3B3);
  static const accent = Color(0xFFE2B579);
  static const onAccent = Color(0xFF281B10);
  static const gold = Color(0xFFECC38C);
  static const rose = Color(0xFFDEA49E);
  static const border = Color(0xFF634A35);
  static const good = Color(0xFFABD1B2);
  static const avoid = Color(0xFFF0A8A5);
}

/// A faint warm wash, keeping content surfaces and text clearly separated.
class BronzeBackground extends StatelessWidget {
  const BronzeBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: BronzePalette.background,
      gradient: RadialGradient(
        center: Alignment.topRight,
        radius: 1.35,
        colors: [
          Color.alphaBlend(
            BronzePalette.gold.withValues(alpha: .06),
            BronzePalette.background,
          ),
          BronzePalette.background,
        ],
      ),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}
