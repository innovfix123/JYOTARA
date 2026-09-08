import 'package:flutter/material.dart';

import 'services/ui_language.dart';

/// Fixed-sign South Indian layout; house numbers are intentionally not inferred.
class SouthIndianChart extends StatelessWidget {
  const SouthIndianChart({
    super.key,
    required this.facts,
    this.title = 'Rasi chart · South Indian layout',
  });
  final Map<String, dynamic> facts;
  final String title;
  static const signs = [
    'Mesha',
    'Vrishabha',
    'Mithuna',
    'Karka',
    'Simha',
    'Kanya',
    'Tula',
    'Vrischika',
    'Dhanu',
    'Makara',
    'Kumbha',
    'Meena',
  ];
  static const cells = [11, 0, 1, 2, 10, -1, -1, 3, 9, -1, -1, 4, 8, 7, 6, 5];
  static int signIndex(Object? value) {
    final normalized = value.toString().toLowerCase().replaceAll(
      RegExp('[^a-z]'),
      '',
    );
    const aliases = [
      ['mesha', 'aries'],
      ['vrishabha', 'vrishabham', 'taurus'],
      ['mithuna', 'mithunam', 'gemini'],
      ['karka', 'karkata', 'karkataka', 'cancer'],
      ['simha', 'leo'],
      ['kanya', 'virgo'],
      ['tula', 'thula', 'libra'],
      ['vrischika', 'vrishchika', 'scorpio'],
      ['dhanu', 'dhanus', 'sagittarius'],
      ['makara', 'capricorn'],
      ['kumbha', 'aquarius'],
      ['meena', 'pisces'],
    ];
    return aliases.indexWhere((names) => names.contains(normalized));
  }

  @override
  Widget build(BuildContext context) {
    final planets = (facts['planets'] as List? ?? []).whereType<Map>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(title),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 130,
          ),
          itemBuilder: (_, cell) {
            final sign = cells[cell];
            if (sign < 0) return const SizedBox.shrink();
            final occupants = planets
                .where((p) => signIndex(p['rasi']) == sign)
                .map((p) => p['name'].toString());
            return Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF66507E)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      signs[sign],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFF2C778),
                      ),
                    ),
                    if (signIndex(facts['lagna']) == sign)
                      const UiText(
                        'Lagnam',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ...occupants.map(
                      (name) =>
                          UiText(name, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (planets.any((p) => signIndex(p['rasi']) < 0))
          const Text(
            'Some sign names could not be placed; see the complete planet list below.',
          ),
      ],
    );
  }
}
