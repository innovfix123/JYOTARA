import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/birth_profile_input.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets(
    'Tamil birth form shows consent and unknown-time limits at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ui = UiLanguagePreferences(write: (_) async {});
      await ui.set('ta');
      await tester.pumpWidget(
        MaterialApp(
          home: UiLanguageScope(
            preferences: ui,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: BirthForm(session: ProfileSession()),
            ),
          ),
        ),
      );
      expect(find.text('உங்கள் பிறப்பு விவரங்கள்'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('gender-prefer_not_to_say')), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gender-prefer_not_to_say')));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('gender-continue')), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gender-continue')));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        250,
        scrollable: scroll,
      );
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text(
          tamilUi['A noon estimate will be used. Rasi/Nakshatra may change during the day; Lagnam and Dasa guidance are withheld.']!,
        ),
        200,
        scrollable: scroll,
      );
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        250,
        scrollable: scroll,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(find.textContaining('தானியங்கி வேத ஜோதிட'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        250,
        scrollable: scroll,
      );
      expect(find.text('என் ஜாதகத்தைக் கணக்கிடவும்'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
  test('saved inputs preserve India clock and reject corrupt cache keys', () {
    final saved = BirthProfileInput.fromKey(
      '2002-07-28T23:30:00Z|11.3428|77.7274|true',
    )!;
    expect(saved.indiaDateTime.day, 29);
    expect(saved.indiaDateTime.hour, 5);
    expect(saved.exactTime, true);
    for (final value in [
      null,
      '',
      '2002-02-30T05:00:00Z|11|77|true',
      '2002-07-29T05:00:00Z|NaN|77|true',
      '2002-07-29T05:00:00Z|91|77|true',
      '2002-07-29T05:00:00Z|11|77|unknown',
    ]) {
      expect(BirthProfileInput.fromKey(value), null);
    }
  });

  testWidgets(
    'edit restores fields without search; nickname stays local and clears on deletion',
    (tester) async {
      String? disk;
      var calls = 0;
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
      );
      JyotaraApiClient api() => JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/astrology/kundli');
          expect(request.body, isNot(contains('Nickname')));
          expect(request.body, isNot(contains('Erode')));
          return http.Response(
            jsonEncode({
              'sandbox': false,
              'chartTicket': 'ticket',
              'profileId': 'profile',
              'result': {
                'data': {
                  'nakshatra_details': {
                    'chandra_rasi': {'name': 'Meena'},
                    'nakshatra': {'name': 'Uttara Bhadrapada'},
                  },
                },
              },
            }),
            200,
          );
        }),
      );
      final first = ProfileSession(api: api(), vault: vault);
      Future<void> save(String nickname) => first.calculate(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11.3428,
        longitude: 77.7274,
        exactTime: true,
        nickname: nickname,
        birthplaceLabel: 'Erode, Tamil Nadu',
      );
      await save('Nickname One');
      await save('Nickname Two');
      await first.flushStorage();
      expect(calls, 1, reason: 'Metadata edit reuses a fresh chart');
      final restored = ProfileSession(api: api(), vault: vault);
      await restored.restore();
      expect(restored.nickname, 'Nickname Two');
      expect(restored.birthplaceLabel, 'Erode, Tamil Nadu');
      await tester.pumpWidget(MaterialApp(home: BirthForm(session: restored)));
      expect(find.text('29/7/2002'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nickname Two'), findsOneWidget);
      final formScroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(formScroll, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('5:00 AM'), 100, scrollable: formScroll);
      expect(find.text('5:00 AM'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Erode, Tamil Nadu'),
        200,
        scrollable: formScroll,
      );
      expect(
        find.widgetWithText(TextField, 'Erode, Tamil Nadu'),
        findsOneWidget,
      );
      expect(calls, 1, reason: 'Opening edit does not search or recalculate');
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        200,
        scrollable: formScroll,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      await restored.clear();
      expect(restored.birthInput, null);
      expect(restored.nickname, '');
      expect(restored.birthplaceLabel, null);
      expect(disk, null);
    },
  );
}
