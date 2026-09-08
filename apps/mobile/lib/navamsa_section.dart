import 'package:flutter/material.dart';

import 'services/ui_language.dart';
import 'south_chart.dart';

class NavamsaSection extends StatelessWidget {
  const NavamsaSection({
    super.key,
    required this.facts,
    required this.birthTimeKnown,
  });
  final Map<String, dynamic> facts;
  final bool birthTimeKnown;
  @override
  Widget build(BuildContext context) {
    final planets = facts['navamsa'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const UiText('Navamsa (D9)', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        if (!birthTimeKnown)
          const UiText(
            'Navamsa is withheld because exact birth time is unknown.',
          )
        else if (planets is! List || planets.length != 9)
          const UiText(
            'Navamsa is unavailable in this saved chart. No extra calculation has been requested automatically.',
          )
        else ...[
          SouthIndianChart(
            facts: {'planets': planets},
            title: 'Navamsa chart · South Indian layout',
          ),
          const SizedBox(height: 8),
          const UiText(
            'Planet positions only; the Navamsa ascendant is not displayed. This is separate from your Rasi chart.',
          ),
        ],
      ],
    );
  }
}
