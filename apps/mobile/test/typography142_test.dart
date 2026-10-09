import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/jyotara_typography.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/premium_onboarding.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets('APK bundles real weight faces for app, chat and Tamil', (
    tester,
  ) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in {
      JyotaraFonts.app: 'Inter',
      JyotaraFonts.editorial: 'Inter',
      JyotaraFonts.chat: 'Roboto',
      JyotaraFonts.tamil: 'NotoSansTamil',
    }.entries) {
      final face = manifest.cast<Map<String, dynamic>>().singleWhere(
        (face) => face['family'] == family.key,
      );
      final fonts = (face['fonts'] as List).cast<Map<String, dynamic>>();
      expect(fonts.map((font) => font['weight']), [400, 500, 600, 700]);
      for (final font in fonts) {
        final asset = font['asset'] as String;
        expect(asset, startsWith('assets/fonts/${family.value}-'));
        final bytes = await rootBundle.load(asset);
        // sfnt signature: these are actual TrueType files, not renamed WOFFs.
        expect(bytes.getUint32(0), 0x00010000);
      }
    }
    for (final license in ['inter', 'roboto', 'notosanstamil']) {
      expect(
        await rootBundle.loadString('assets/fonts/$license-OFL.txt'),
        contains('SIL OPEN FONT LICENSE'),
      );
    }
  });

  testWidgets('root theme uses Inter and keeps Tamil fallback on headings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = UiLanguagePreferences(write: (_) async {});
    await tester.pumpWidget(JyotaraApp(uiPreferences: preferences));
    final english = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(english.textTheme.bodyMedium!.fontFamily, JyotaraFonts.app);
    expect(english.textTheme.headlineMedium!.fontFamily, JyotaraFonts.app);
    expect(english.textTheme.headlineMedium!.fontWeight, FontWeight.w500);
    expect(english.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(english.appBarTheme.titleTextStyle!.fontFamily, JyotaraFonts.app);
    await preferences.set('ta');
    await tester.pump();
    final tamil = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    for (final style in [
      tamil.textTheme.displaySmall!,
      tamil.textTheme.headlineMedium!,
      tamil.textTheme.headlineSmall!,
      tamil.textTheme.bodyMedium!,
    ]) {
      expect(style.fontFamilyFallback, contains(JyotaraFonts.tamil));
      expect(style.letterSpacing, 0);
      expect(style.height, greaterThanOrEqualTo(1.45));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['en', 'ta']) {
    testWidgets('bundled fonts fit $language Home and onboarding text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final entry in {
          JyotaraFonts.app: 'Inter-Regular',
          JyotaraFonts.editorial: 'Inter-Medium',
          JyotaraFonts.tamil: 'NotoSansTamil-Regular',
        }.entries) {
          await (FontLoader(entry.key)
                ..addFont(rootBundle.load('assets/fonts/${entry.value}.ttf')))
              .load();
        }
      });
      final preferences = UiLanguagePreferences(write: (_) async {});
      await preferences.set(language);
      final theme = ThemeData(
        fontFamily: JyotaraFonts.app,
        fontFamilyFallback: JyotaraFonts.fallback,
        textTheme: jyotaraAppTextTheme(tamil: language == 'ta'),
      );
      Widget languageScope(BuildContext context, Widget? child) =>
          UiLanguageScope(
            preferences: preferences,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: languageScope,
          home: Scaffold(body: HomeScreen(onOpenChat: (_) {})),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('homeScroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: languageScope,
          home: const Scaffold(body: AccountScreen()),
        ),
      );
      await tester.pump();
      final profileText = find
          .descendant(
            of: find.byType(AccountScreen),
            matching: find.byType(Text),
          )
          .first;
      expect(
        DefaultTextStyle.of(tester.element(profileText))
            .style
            .fontFamilyFallback,
        contains(JyotaraFonts.tamil),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: languageScope,
          home: Scaffold(
            body: OnboardingTheme(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    language == 'ta'
                        ? 'உங்களுக்காக உருவாக்கப்பட்டது.'
                        : 'Made for you.',
                    style: onboardingHeading(38),
                  ),
                  const Text('தமிழ் · English'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final style = tester.widget<Text>(find.text('தமிழ் · English')).style;
      expect(style, isNull);
      expect(
        DefaultTextStyle.of(tester.element(find.text('தமிழ் · English')))
            .style
            .fontFamilyFallback,
        contains(JyotaraFonts.tamil),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
