import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/ui_language.dart';

Map<String, String> window(String start, String end) => {
  'start': '2026-10-09T$start:00+05:30',
  'end': '2026-10-09T$end:00+05:30',
};

String clock(dynamic raw) {
  final date = DateTime.parse('$raw')
      .toUtc()
      .add(const Duration(hours: 5, minutes: 30));
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('partial overlap resumes focus only before the actual good end', () {
    expect(
      dailyTimingOverlapExplanation(
        window('11:43', '12:30'),
        window('10:37', '12:06'),
        tamil: false,
        clock: clock,
      ),
      'These times overlap. Take it slow until 12:06, then focus until 12:30.',
    );
  });

  test('fully covered good time has no later focus promise', () {
    final text = dailyTimingOverlapExplanation(
      window('11:43', '12:30'),
      window('10:37', '13:06'),
      tamil: false,
      clock: clock,
    );
    expect(text, 'These times overlap. Take it slow during 11:43–12:30.');
    expect(text, isNot(contains('then focus')));
  });

  test(
    'good time ending inside avoid explains only the overlapping period',
    () {
      expect(
        dailyTimingOverlapExplanation(
          window('10:00', '11:00'),
          window('10:37', '12:06'),
          tamil: false,
          clock: clock,
        ),
        'These times overlap. Take it slow during 10:37–11:00.',
      );
    },
  );

  test('avoid inside good time preserves both actual overlap boundaries', () {
    expect(
      dailyTimingOverlapExplanation(
        window('10:00', '13:00'),
        window('10:37', '12:06'),
        tamil: false,
        clock: clock,
      ),
      'These times overlap. Take it slow from 10:37 until 12:06, then focus until 13:00.',
    );
  });

  test('nonoverlap, touching endpoints and incomplete timings add no note', () {
    for (final good in [
      window('12:30', '13:00'),
      window('12:06', '13:00'),
      window('09:00', '10:37'),
      window('13:00', '12:30'),
      {'start': 'invalid', 'end': 'invalid'},
      null,
    ]) {
      expect(
        dailyTimingOverlapExplanation(
          good,
          window('10:37', '12:06'),
          tamil: false,
          clock: clock,
        ),
        isNull,
      );
    }
  });

  for (final language in ['en', 'ta']) {
    testWidgets(
      'Daily overlap explanation stays inside opened timing guide $language',
      (tester) async {
        final prefs = UiLanguagePreferences(write: (_) async {});
        await prefs.set(language);
        await tester.pumpWidget(
          UiLanguageScope(
            preferences: prefs,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: DailyHoroscopeScreen(
                readCity: () async => jsonEncode({
                  'name': 'Bengaluru',
                  'lat': 12.97,
                  'lon': 77.59,
                }),
                request: (_, body) async => {
                  'sections': [],
                  'timings': [
                    {'name': 'Rahu Kalam', ...window('10:37', '12:06')},
                    {'name': 'Abhijit Muhurta', ...window('11:43', '12:30')},
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.ensureVisible(find.byKey(const Key('dailySeeYourDay')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('dailySeeYourDay')));
        await tester.pumpAndSettle();
        final note = find.byKey(const Key('dailyTimingOverlap'));
        expect(note, findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('dailyTimingGuide')),
            matching: note,
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(note).data,
          language == 'en'
              ? 'These times overlap. Take it slow until 12:06 PM, then focus until 12:30 PM.'
              : 'இந்த நேரங்கள் ஒன்றுடன் ஒன்று சேர்கின்றன. 12:06 பிற்பகல் வரை நிதானமாக இருங்கள்; பிறகு 12:30 பிற்பகல் வரை கவனமாகச் செயல்படுங்கள்.',
        );
        expect(find.textContaining('11:43'), findsOneWidget);
        expect(find.textContaining('10:37'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Daily nonoverlapping timings have no explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: DailyHoroscopeScreen(
          readCity: () async =>
              jsonEncode({'name': 'Bengaluru', 'lat': 12.97, 'lon': 77.59}),
          request: (_, body) async => {
            'sections': [],
            'timings': [
              {'name': 'Rahu Kalam', ...window('10:37', '12:06')},
              {'name': 'Abhijit Muhurta', ...window('12:30', '13:00')},
            ],
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.ensureVisible(find.byKey(const Key('dailySeeYourDay')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dailySeeYourDay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dailyTimingOverlap')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
