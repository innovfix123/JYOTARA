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
    'Tamil UI requests Tamil daily content independently of English chat',
    (tester) async {
      languagePreferences.value = 'english';
      final ui = UiLanguagePreferences(write: (_) async {});
      await ui.set('ta');
      String? requested;
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: ui,
          child: MaterialApp(
            home: DailyHoroscopeScreen(
              request: (_, body) async {
                requested ??= body['language'] as String;
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
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, 'ta');
      await tester.scrollUntilVisible(
        find.text('தனிப்பட்ட கவனம்'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('இன்று தெளிவாகப் பேசுங்கள்.'), findsOneWidget);
      expect(find.text('Money · everyday reminder'), findsNothing);
    },
  );

  testWidgets('English UI keeps daily content English when chat is Tamil', (
    tester,
  ) async {
    languagePreferences.value = 'tamil';
    String? requested;
    final dates = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DailyHoroscopeScreen(
          request: (_, body) async {
            requested = body['language'] as String;
            dates.add(body['date'] as String);
            return {
              'sections': [
                {
                  'title': 'General',
                  'text': 'A steady day.',
                  'details': 'General reading.',
                },
              ],
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, 'en');
    expect(find.text('Jyotara'), findsOneWidget);
    expect(find.text('Relationships'), findsOneWidget);
    expect(find.text('Work & studies'), findsOneWidget);
    expect(find.text('Personal focus'), findsOneWidget);
    expect(find.text('Yesterday'), findsNothing);
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(
      DateTime.parse(dates.last).difference(DateTime.parse(dates.first)).inDays,
      1,
    );
    await tester.ensureVisible(find.text('Personal focus'));
    await tester.tap(find.text('Personal focus'));
    await tester.pumpAndSettle();
    expect(
      find.text('General reading.'),
      findsNothing,
    ); // No long detail popup.
  });
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
