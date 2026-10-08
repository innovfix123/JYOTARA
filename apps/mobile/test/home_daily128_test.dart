import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/brand_mark.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:jyotara/route_nav.dart';
import 'package:jyotara/services/name_display.dart';

void main() {
  test(
    'Tamil greeting transliterates display name without replacing stored text',
    () {
      expect(tamilDisplayName('Saran'), 'சரண்');
      expect(tamilDisplayName('Saran Keerthi'), 'சரண் கீர்த்தி');
      expect(tamilDisplayName('சரண்'), 'சரண்');
    },
  );
  Future<void> fonts() async {
    await ui.loadFontFromList(
      await File(
        '/Users/apple/Documents/Startup/source/jyotara/docs/qa/2026-10-07/home-daily128/device-tamil-font.ttf',
      ).readAsBytes(),
      fontFamily: 'sans-serif',
    );
    for (final f in {
      'JyotaraEditorial': 'CormorantGaramond',
      'JyotaraSans': 'Manrope',
    }.entries) {
      await (FontLoader(
        f.key,
      )..addFont(rootBundle.load('assets/fonts/${f.value}.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }

  for (final language in ['en', 'ta']) {
    testWidgets(
      'Home uses simple guide icons and routes Ask topics in $language',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(fonts);
        final prefs = UiLanguagePreferences(write: (_) async {});
        await prefs.set(language);
        await tester.pumpWidget(
          UiLanguageScope(
            preferences: prefs,
            child: MaterialApp(
              theme: ThemeData(
                fontFamily: 'JyotaraSans',
                fontFamilyFallback: const ['sans-serif'],
              ),
              home: Scaffold(
                body: MainTabScope(child: HomeScreen(onOpenChat: (_) {})),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('homeMatching')), findsOneWidget);
        expect(find.byKey(const Key('homeGuideGroup')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('homeDaily')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('homeDaily')));
        await tester.pump();
        expect(requestedMainTab.value, 1);
        final dailySize = tester.getSize(find.byKey(const Key('homeDaily')));
        final kundliSize = tester.getSize(find.byKey(const Key('homeKundli')));
        expect(dailySize.width, dailySize.height);
        expect(kundliSize, dailySize);
        requestedMainTab.value = null;
        expect(find.byKey(const Key('homeFamily')), findsNothing);
        expect(find.text(language == 'en' ? 'Meera' : 'மீரா'), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('homeMatching')));
        await tester.pump();
        await tester.ensureVisible(
          find.text(language == 'en' ? 'Education' : 'கல்வி'),
        );
        await tester.tap(find.text(language == 'en' ? 'Education' : 'கல்வி'));
        await tester.pump();
        expect(requestedAskGroup.value, 'Education & Hobbies');
        expect(requestedMainTab.value, 3);
        await tester.tap(find.text(language == 'en' ? 'Family' : 'குடும்பம்'));
        await tester.pump();
        expect(requestedAskGroup.value, 'Family & Personal Life');
        await tester.tap(find.byKey(const Key('homeAskNow')));
        await tester.pump();
        expect(requestedAskGroup.value, 'All');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        requestedMainTab.value = null;
        requestedAskGroup.value = 'All';
      },
    );
  }
  testWidgets(
    'Daily uses live timings and changes day; long reading opens on demand',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = profileSession.birthTimeKnown;
      profileSession.birthTimeKnown = true;
      addTearDown(() => profileSession.birthTimeKnown = old);
      final calls = <Map<String, dynamic>>[];
      await tester.runAsync(fonts);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'JyotaraSans',
              ),
            ),
            home: DailyHoroscopeScreen(
              readCity: () async =>
                  jsonEncode({'name': 'Chennai', 'lat': 13.08, 'lon': 80.27}),
              request: (path, body) async {
                calls.add({...body, 'path': path});
                return {
                  'sections': [
                    {
                      'title': 'General',
                      'text': 'A calm start. Longer reading is available here.',
                    },
                    {
                      'title': 'Health',
                      'text': 'Keep a steady pace; make room for rest.',
                    },
                    {
                      'title': 'Love',
                      'text':
                          'Say what you feel, gently. Listen before reacting.',
                    },
                    {
                      'title': 'Career',
                      'text':
                          'Focus on one thing; give decisions a little time.',
                    },
                  ],
                  'timings': [
                    {
                      'name': 'Abhijit Muhurta',
                      'start': '${body['date']}T10:30:00+05:30',
                      'end': '${body['date']}T12:00:00+05:30',
                    },
                    {
                      'name': 'Rahu Kalam',
                      'start': '${body['date']}T15:00:00+05:30',
                      'end': '${body['date']}T16:30:00+05:30',
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('10:30 AM–12:00 PM'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('dailyApproach')));
      await tester.tap(find.byKey(const Key('dailyApproach')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('Physical'), findsOneWidget);
      expect(find.textContaining('Longer reading'), findsNothing);
      expect(find.byKey(const Key('dailyApprovedLotus')), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/Users/apple/Documents/Startup/source/jyotara/docs/qa/2026-10-07/home-daily128/daily-flutter.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.ensureVisible(find.byKey(const Key('dailyFullReading')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dailyFullReading')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.textContaining('Longer reading'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Relationships'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Relationships'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('Listen before reacting.'), findsOneWidget);
      expect(find.textContaining('Longer reading'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.text('Tomorrow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final daily = calls
          .where((c) => c['path'] == '/api/horoscope/daily')
          .toList();
      expect(daily.length, 2);
      expect(daily.first['date'], isNot(daily.last['date']));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Daily keeps Tamil after a late English response and shows Tamil times',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = profileSession.birthTimeKnown;
      profileSession.birthTimeKnown = true;
      addTearDown(() => profileSession.birthTimeKnown = old);
      final prefs = UiLanguagePreferences(write: (_) async {});
      final english = Completer<Map<String, dynamic>>();
      final calls = <String>[];
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: prefs,
          child: MaterialApp(
            home: DailyHoroscopeScreen(
              readCity: () async =>
                  jsonEncode({'name': 'Chennai', 'lat': 13.08, 'lon': 80.27}),
              request: (path, body) async {
                if (path == '/api/horoscope/daily') {
                  calls.add('${body['language']}');
                  if (body['language'] == 'en') return english.future;
                  return {
                    'language': 'ta',
                    'sections': [
                      for (final title in [
                        'General',
                        'Health',
                        'Love',
                        'Career',
                      ])
                        {
                          'title': title,
                          'text': 'நிதானமாக செயல்படுங்கள்.',
                          'details': 'நிதானமாக செயல்படுங்கள். உங்கள் திட்டத்தை கவனமாகப் பாருங்கள்.',
                        },
                    ],
                  };
                }
                return {
                  'timings': [
                    {
                      'name': 'Rahu Kalam',
                      'start': '${body['date']}T12:00:00+05:30',
                      'end': '${body['date']}T13:30:00+05:30',
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await prefs.set('ta');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      english.complete({
        'language': 'en',
        'sections': [
          {'title': 'Health', 'text': 'English must not replace Tamil.'},
        ],
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('dailyApproach')));
      await tester.tap(find.byKey(const Key('dailyApproach')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls, ['en', 'ta']);
      expect(find.text('English must not replace Tamil.'), findsNothing);
      expect(find.text('உடல்'), findsOneWidget);
      expect(find.text('சென்னை'), findsOneWidget);
      expect(find.textContaining('மதியம்'), findsWidgets);
      expect(find.textContaining(' PM'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('dailyFullReading')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dailyFullReading')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('உங்கள் திட்டத்தை கவனமாகப் பாருங்கள்.'), findsOneWidget);
      expect(find.text('Relationships'), findsNothing);
    },
  );
}
