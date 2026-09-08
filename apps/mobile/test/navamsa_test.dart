import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/chart_facts.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:jyotara/navamsa_section.dart';
import 'package:jyotara/south_chart.dart';

Map<String, dynamic> fixture() => {
  'status': 'ok',
  'data': {
    'divisional_positions': List.generate(
      12,
      (id) => {
        'rasi': {'id': id, 'name': SouthIndianChart.signs[id]},
        'planet_positions': id < 9
            ? [
                {
                  'planet': {
                    'id': id < 7 ? id : id + 94,
                    'name': [
                      'Sun',
                      'Moon',
                      'Mercury',
                      'Venus',
                      'Mars',
                      'Jupiter',
                      'Saturn',
                      'Rahu',
                      'Ketu',
                    ][id],
                  },
                  'rasi': {'id': id, 'name': SouthIndianChart.signs[id]},
                  'sign_degree': 12.5,
                },
              ]
            : [],
      },
    ),
  },
};
void main() {
  test('D9 preserves node IDs and sign convention without natal substitution', () {
    final result = normalizeNavamsa(fixture(), true)!;
    expect(result.length, 9);
    expect(result.first['position'], 1);
    expect(result[7]['name'], 'Rahu');
    expect(result[8]['name'], 'Ketu');
    expect(result.any((p) => p.containsKey('isRetrograde')), false);
    expect(normalizeNavamsa(fixture(), false), isNull);
    expect(normalizeNavamsa(null, true), isNull);
    final malformed = fixture();
    malformed['data']['divisional_positions'][7]['planet_positions'][0]['planet']['id'] =
        7;
    expect(normalizeNavamsa(malformed, true), isNull);
    final badDegree = fixture();
    badDegree['data']['divisional_positions'][0]['planet_positions'][0]['sign_degree'] =
        30;
    expect(normalizeNavamsa(badDegree, true), isNull);
  });
  for (final language in ['en', 'ta']) {
    testWidgets(
      'D9 shows real separate data and missing states in $language at large text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ui = UiLanguagePreferences(write: (_) async {});
        await ui.set(language);
        Future<void> show(Map<String, dynamic> facts, bool known) async {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => UiLanguageScope(
                preferences: ui,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: NavamsaSection(facts: facts, birthTimeKnown: known),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await show({
          'navamsa': normalizeNavamsa(fixture(), true),
          'lagna': 'Meena',
        }, true);
        expect(find.byType(SouthIndianChart), findsOneWidget);
        expect(find.text(language == 'ta' ? 'மேஷம்' : 'Mesha'), findsOneWidget);
        expect(find.text('Lagnam'), findsNothing);
        expect(find.text('லக்னம்'), findsNothing);
        await show({}, true);
        expect(find.byType(SouthIndianChart), findsNothing);
        expect(
          find.text(
            language == 'ta'
                ? tamilUi['Navamsa is unavailable in this saved chart. No extra calculation has been requested automatically.']!
                : 'Navamsa is unavailable in this saved chart. No extra calculation has been requested automatically.',
          ),
          findsOneWidget,
        );
        await show({'navamsa': normalizeNavamsa(fixture(), true)}, false);
        expect(find.byType(SouthIndianChart), findsNothing);
      },
    );
  }
}
