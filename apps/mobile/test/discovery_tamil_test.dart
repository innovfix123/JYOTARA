import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:jyotara/main.dart' show languagePreferences;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() => languagePreferences.value = 'auto');
  testWidgets(
    'Tamil chat preference requests Tamil daily content even with English UI',
    (tester) async {
      languagePreferences.value = 'tamil';
      String? requested;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyHoroscopeScreen(
            request: (_, body) async {
              requested = body['language'] as String;
              return {
                'sections': [
                  {
                    'title': 'General',
                    'text': 'இன்று தெளிவாகப் பேசுங்கள்.',
                    'details': 'விரிவான தமிழ்ப் பலன்.',
                  },
                ],
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, 'ta');
      await tester.scrollUntilVisible(
        find.text('பொதுப் பலன்'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('இன்று தெளிவாகப் பேசுங்கள்.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('பணம் · அன்றாட நினைவூட்டல்'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Money · everyday reminder'), findsNothing);
    },
  );
  testWidgets(
    'Tamil app preference localises Kundli library heading and create action',
    (tester) async {
      final ui = UiLanguagePreferences(write: (_) async {});
      await ui.set('ta');
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: ui,
          child: const MaterialApp(home: KundliLibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('இலவச ஜாதகம்'), findsOneWidget);
      expect(
        find.text('உங்களுக்குத் தெரிந்தவர்களின் ஜாதகங்கள்'),
        findsOneWidget,
      );
      expect(find.text('புதிய ஜாதகம் உருவாக்கவும்'), findsOneWidget);
    },
  );
  testWidgets('Tamil matching localises form and validation dialog', (
    tester,
  ) async {
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    await tester.pumpWidget(
      UiLanguageScope(
        preferences: ui,
        child: const MaterialApp(home: MatchingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ஜாதகப் பொருத்தம்'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ஜாதகப் பொருத்தம் பார்க்கவும்'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('ஜாதகப் பொருத்தம் பார்க்கவும்'));
    await tester.pumpAndSettle();
    expect(find.text('பொருத்த விவரங்களைச் சரிபார்க்கவும்'), findsOneWidget);
  });
}
