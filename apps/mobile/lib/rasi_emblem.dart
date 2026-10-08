import 'package:flutter/material.dart';

import 'bronze_theme.dart';
import 'services/ui_language.dart';
import 'south_chart.dart';

const rasiEmblemAsset = 'assets/images/profile-rasi139.png';

/// The approved atlas has individually measured cells, not a uniform grid.
/// Keeping these windows inside each rim prevents neighbouring signs leaking.
const rasiEmblemCenters = <Offset>[
  Offset(188, 186),
  Offset(545, 185.5),
  Offset(902, 185.5),
  Offset(1259.5, 185.5),
  Offset(187.5, 529.5),
  Offset(544.5, 529.5),
  Offset(901, 529),
  Offset(1259.5, 529.5),
  Offset(188, 868.5),
  Offset(545, 869.5),
  Offset(901, 870),
  Offset(1259, 869.5),
];

class RasiEmblem extends StatelessWidget {
  const RasiEmblem({super.key, required this.index, this.size = 76});
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final valid = index >= 0 && index < 12;
    return Semantics(
      label: valid
          ? '${uiText(context, SouthIndianChart.signs[index])} ${uiText(context, 'Rasi')}'
          : uiText(context, 'Your profile'),
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: valid
            ? ClipOval(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final scale = bounds.maxWidth / 338;
                    final center = rasiEmblemCenters[index];
                    return Stack(
                      children: [
                        Positioned(
                          left: -(center.dx - 169) * scale,
                          top: -(center.dy - 169) * scale,
                          width: 1448 * scale,
                          height: 1086 * scale,
                          child: Image.asset(
                            rasiEmblemAsset,
                            filterQuality: FilterQuality.high,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BronzePalette.card,
                  border: Border.all(color: BronzePalette.border),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: size * .42,
                  color: BronzePalette.gold,
                ),
              ),
      ),
    );
  }
}
