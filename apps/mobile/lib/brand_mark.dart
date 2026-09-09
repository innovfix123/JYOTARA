import 'package:flutter/material.dart';

/// Approved gold rasi wheel shared by launch, welcome and navigation.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      'assets/images/jyotara_rasi_logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'Jyotara',
    ),
  );
}

/// Each atlas cell contains one sign, ordered Aries through Pisces.
class RasiFigure extends StatelessWidget {
  const RasiFigure({super.key, required this.index, this.size = 58});
  final int index;
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
                  'assets/images/rasi_figures.png',
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
