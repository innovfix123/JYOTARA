import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/brand_mark.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets(
    'all rasi labels follow UI language without changing sign identity',
    (tester) async {
      final prefs = UiLanguagePreferences(
        read: () async => 'en',
        write: (_) async {},
      );
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: prefs,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const BrandMark(),
                    for (var i = 0; i < 12; i++)
                      Row(
                        children: [
                          RasiFigure(index: i, size: 24),
                          Text(zodiacLabel(context, i)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Mesha · Aries'), findsOneWidget);
      expect(find.byType(RasiFigure), findsNWidgets(12));
      await prefs.set('ta');
      await tester.pumpAndSettle();
      for (final name in [
        'மேஷம்',
        'ரிஷபம்',
        'மிதுனம்',
        'கடகம்',
        'சிம்மம்',
        'கன்னி',
        'துலாம்',
        'விருச்சிகம்',
        'தனுசு',
        'மகரம்',
        'கும்பம்',
        'மீனம்',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Mesha · Aries'), findsNothing);
      await prefs.set('en');
      await tester.pumpAndSettle();
      expect(find.text('Meena · Pisces'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
