import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/celestial_welcome.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/main.dart' show accountStorage, profileSession;
import 'package:jyotara/rasi_emblem.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    accountStorage.account = null;
  });

  Future<void> choose(WidgetTester tester, bool first) async {
    final card = find.byKey(
      ValueKey(first ? 'matching-first' : 'matching-second'),
    );
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  test(
    'portrait welcome fills height and keeps the approved central title',
    () {
      for (final size in [const Size(360, 800), const Size(384, 850)]) {
        final frame = welcomeFrameBounds(size, 9 / 16);
        expect(frame.height, size.height);
        expect(frame.width, greaterThan(size.width));
        final title = Rect.fromLTRB(
          frame.left + frame.width * .32,
          frame.top + frame.height * .69,
          frame.left + frame.width * .68,
          frame.top + frame.height * .81,
        );
        expect((Offset.zero & size).contains(title.topLeft), isTrue);
        expect((Offset.zero & size).contains(title.bottomRight), isTrue);
      }
      for (final size in [const Size(800, 360), const Size(240, 1000)]) {
        final frame = welcomeFrameBounds(size, 9 / 16);
        expect(frame.width, lessThanOrEqualTo(size.width));
        expect(frame.height, lessThanOrEqualTo(size.height));
      }
    },
  );

  testWidgets('new matching person uses saved Birth Chart and actual Rasi', (
    tester,
  ) async {
    final saved = <SavedKundli>[];
    var chartCalls = 0;
    final ownNickname = profileSession.nickname;
    final ownFacts = profileSession.facts;
    final created = ProfileSession(
      api: JyotaraApiClient(
        baseUrl: 'https://fixture.test',
        client: MockClient((_) async {
          chartCalls++;
          final body = jsonDecode(chartReply('friend').body);
          body['result']['data']['nakshatra_details']['chandra_rasi']['name'] =
              'Simha';
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingScreen(
          loadKundlis: () async => saved,
          createKundli: (rows) async {
            expect(rows.any((r) => r.id == 'personal'), isFalse);
            final row = SavedKundli('friend', created);
            saved.add(row);
            return row;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, false);
    await tester.tap(find.text('Add new person'));
    await tester.pumpAndSettle();
    final form = tester.widget<BirthForm>(find.byType(BirthForm));
    expect(
      form.onSubmit,
      isNull,
      reason: 'Use the normal saved-chart calculation, not a detached draft callback.',
    );
    expect(form.onboarding, isTrue);
    expect(form.initialDetails, isNull);
    expect(form.session, same(created));
    expect(form.session, isNot(same(profileSession)));
    await created.calculate(
      dateTime: '1995-01-10T08:30:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
      nickname: 'Divya',
      birthplaceLabel: 'Erode',
    );
    Navigator.of(tester.element(find.byType(BirthForm))).pop();
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('matching-second'));
    final emblem = tester.widget<RasiEmblem>(
      find.descendant(of: card, matching: find.byType(RasiEmblem)),
    );
    expect(emblem.index, 4);
    expect(find.text('Simha Rasi'), findsOneWidget);
    expect(chartCalls, 1);
    expect(profileSession.nickname, ownNickname);
    expect(profileSession.facts, ownFacts);
    await choose(tester, false);
    expect(find.byKey(const ValueKey('matching-saved-friend')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    created.dispose();
  });

  testWidgets(
    'cancelling a new person removes only its unfinished saved chart',
    (tester) async {
      final session = ProfileSession();
      final saved = <SavedKundli>[];
      var removed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MatchingScreen(
            loadKundlis: () async => saved,
            createKundli: (_) async {
              final row = SavedKundli('empty', session);
              saved.add(row);
              return row;
            },
            removeKundli: (row, rows) async {
              expect(row.id, 'empty');
              expect(rows.map((r) => r.id), ['empty']);
              removed++;
              saved.remove(row);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, false);
      await tester.tap(find.text('Add new person'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(BirthForm))).pop();
      await tester.pumpAndSettle();
      expect(removed, 1);
      expect(saved, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('saved-chart deletion can retry after a server failure', () async {
    var fail = true;
    var deletes = 0;
    String? disk;
    final session = ProfileSession(
      vault: LocalProfileVault(
        read: () async => disk,
        write: (value) async => disk = value,
      ),
      api: JyotaraApiClient(
        baseUrl: 'https://fixture.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('kundli')) return chartReply('saved');
          deletes++;
          if (fail) throw http.ClientException('fixture offline');
          return http.Response(
            jsonEncode({'deleted': true, 'scope': 'anonymous_chart_session'}),
            200,
          );
        }),
      ),
    );
    await session.calculate(
      dateTime: '1995-01-10T08:30:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    await session.flushStorage();
    final row = SavedKundli('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', session);
    await const FlutterSecureStorage().write(
      key: KundliLibrary.indexKey,
      value: jsonEncode([row.id]),
    );
    await expectLater(
      KundliLibrary.remove(row, [row]),
      throwsA(isA<JyotaraApiException>()),
    );
    expect(session.storageError, isNotNull);
    expect(session.facts, isNotNull);
    fail = false;
    await KundliLibrary.remove(row, [row]);
    expect(deletes, 2);
    expect(session.facts, isNull);
    expect(disk, isNull);
    expect(
      jsonDecode(
        (await const FlutterSecureStorage().read(key: KundliLibrary.indexKey))!,
      ),
      isEmpty,
    );
    session.dispose();
  });

  testWidgets(
    'saved-person Delete confirms once and clears picker and selection',
    (tester) async {
      final session = ProfileSession(
        api: JyotaraApiClient(
          baseUrl: 'https://fixture.test',
          client: MockClient((_) async => chartReply('friend')),
        ),
      );
      await session.calculate(
        dateTime: '1995-01-10T08:30:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
        nickname: 'Divya',
      );
      final row = SavedKundli('friend', session);
      final saved = [row];
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MatchingScreen(
            loadKundlis: () async => saved,
            removeKundli: (removed, _) async {
              calls++;
              saved.remove(removed);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, false);
      await tester.tap(find.byKey(const ValueKey('matching-saved-friend')));
      await tester.pumpAndSettle();
      await choose(tester, false);
      await tester.tap(find.byKey(const ValueKey('matching-delete-friend')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Divya'), findsOneWidget);
      await choose(tester, false);
      await tester.tap(find.byKey(const ValueKey('matching-delete-friend')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Divya'), findsNothing);
      await choose(tester, false);
      expect(find.byKey(const ValueKey('matching-saved-friend')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'removing a legacy saved person also clears selected comparison',
    (tester) async {
      final person = <String, dynamic>{
        'nickname': 'Legacy friend',
        'datetime': '1995-01-10T08:30:00+05:30',
        'latitude': 11.0,
        'longitude': 77.0,
        'exactTime': true,
        'birthplaceLabel': 'Erode',
      };
      FlutterSecureStorage.setMockInitialValues({
        'jyotara.matching.people.v1': jsonEncode([person]),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MatchingScreen(
            loadKundlis: () async => [],
            resolveRasi: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, false);
      await tester.tap(find.text('Legacy friend'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy friend'), findsOneWidget);
      await choose(tester, false);
      await tester.tap(find.byTooltip('Remove saved person'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy friend'), findsNothing);
      await choose(tester, false);
      expect(find.text('Legacy friend'), findsNothing);
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(
            key: 'jyotara.matching.people.v1',
          ))!,
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final language in ['en', 'ta']) {
    testWidgets(
      'Daily everyday timing copy keeps real intervals in $language',
      (tester) async {
        final prefs = UiLanguagePreferences(write: (_) async {});
        await prefs.set(language);
        await tester.pumpWidget(
          UiLanguageScope(
            preferences: prefs,
            child: MaterialApp(
              home: DailyHoroscopeScreen(
                readCity: () async =>
                    jsonEncode({'name': 'Chennai', 'lat': 13.08, 'lon': 80.27}),
                request: (_, body) async => {
                  'sections': [],
                  'timings': [
                    {
                      'name': 'Rahu Kalam',
                      'start': '2026-10-09T02:00:00Z',
                      'end': '2026-10-09T03:30:00Z',
                    },
                    {
                      'name': 'Abhijit Muhurta',
                      'start': '2026-10-09T06:00:00Z',
                      'end': '2026-10-09T07:00:00Z',
                    },
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.ensureVisible(find.byKey(const Key('dailyPlan')));
        await tester.pump();
        expect(
          find.text(language == 'en' ? 'Today’s timings' : 'இன்றைய நேரங்கள்'),
          findsOneWidget,
        );
        expect(
          find.text(language == 'en' ? 'FOCUS TIME' : 'கவனமாகச் செயல்பட'),
          findsOneWidget,
        );
        expect(
          find.text(language == 'en' ? 'TAKE IT SLOW' : 'நிதானமாக இருங்கள்'),
          findsOneWidget,
        );
        expect(find.textContaining('11:30'), findsOneWidget);
        expect(find.text('GOOD TIME'), findsNothing);
        expect(find.text('AVOID TIME'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byType(PopupMenuButton<int>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(language == 'en' ? 'Tomorrow' : 'நாளை'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.ensureVisible(find.byKey(const Key('dailyPlan')));
        expect(
          find.text(language == 'en' ? 'Tomorrow’s timings' : 'நாளைய நேரங்கள்'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Explore unavailable reading does not announce a payment requirement',
    (tester) async {
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingPanel(
              session: session,
              title: 'Personality & strengths',
              topic: 'Daily',
              question: 'Reflect on my strengths.',
              language: 'en',
            ),
          ),
        ),
      );
      expect(find.text('Personality & strengths'), findsOneWidget);
      expect(find.textContaining('paid access'), findsNothing);
      expect(find.textContaining('free'), findsNothing);
      expect(
        find.text(
          'Readings are temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
