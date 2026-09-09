import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  testWidgets('account consent status updates without reopening', (
    tester,
  ) async {
    profileSession.setResearchConsent(false);
    addTearDown(() => profileSession.setResearchConsent(false));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountScreen())),
    );
    await tester.scrollUntilVisible(find.text('Privacy & consent'), 200);
    expect(find.text('Research sharing is off'), findsOneWidget);
    profileSession.setResearchConsent(true);
    await tester.pump();
    expect(
      find.text('Research sharing is on for this session'),
      findsOneWidget,
    );
    profileSession.setResearchConsent(false);
    await tester.pump();
    expect(find.text('Research sharing is off'), findsOneWidget);
  });
  for (final outcome in ['success', 'failure', 'profile-change']) {
    testWidgets('pending chat survives reopening: $outcome', (tester) async {
      final response = Completer<http.Response>();
      var questionCalls = 0;
      final session = ProfileSession(
        api: JyotaraApiClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('kundli')) {
              return http.Response(
                jsonEncode({
                  'sandbox': false,
                  'chartTicket': 'TEST-ONLY-ticket',
                  'profileId': 'test-profile',
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
            }
            if (jsonDecode(request.body)['question'] == 'Show the selected profile rasi, nakshatra and current Saturn status.') {
              return http.Response(jsonEncode({'profileId':'test-profile','answer':'Your rasi is Meena.','answerMode':'chart_guidance','evidence':[]}),200);
            }
            questionCalls++;
            return response.future;
          }),
        ),
      );
      await session.calculate(
        dateTime: '2000-01-01T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      Widget screen() => MaterialApp(
        home: ChatScreen(guide: guides[1], session: session),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'Career question',
      );
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pump();
      expect(questionCalls, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(session.conversation(guides[1].name).pending, true);
      if (outcome == 'profile-change') session.clear();
      response.complete(
        outcome == 'failure'
            ? http.Response('{}', 503)
            : http.Response(
                jsonEncode({
                  'profileId': 'test-profile',
                  'answer': 'Delayed provider answer',
                  'evidence': [],
                }),
                200,
              ),
      );
      await tester.pumpAndSettle();
      expect(session.conversation(guides[1].name).pending, false);
      expect(questionCalls, 1);
      if (outcome == 'success') {
        expect(find.textContaining('Delayed provider answer'), findsOneWidget);
      } else if (outcome == 'failure') {
        expect(
          session.conversation(guides[1].name).messages.last.label,
          'ANSWER NOT CONFIRMED',
        );
      } else {
        expect(find.textContaining('Delayed provider answer'), findsNothing);
        expect(find.text('Career question'), findsNothing);
      }
    });
  }
  testWidgets('English navigation opens', (tester) async {
    await tester.pumpWidget(const JyotaraApp());
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.tap(find.byKey(const Key('enterApp')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Your AI Vedic Guides'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Your AI Vedic Guides'), findsOneWidget);
    expect(find.text('Chart'), findsOneWidget);
  });

  for (final entry in {
    'english': 'Should I move to Chennai for work?',
    'tamil': 'என் வேலை வாய்ப்பு எப்படி?',
    'tanglish': 'Enaku job change panna nalla time ah?',
  }.entries) {
    testWidgets(
      'chat sends real request in ${entry.key}, shows response evidence',
      (tester) async {
        var questionCalls = 0;
        final session = ProfileSession(
          api: JyotaraApiClient(
            client: MockClient((request) async {
              if (request.url.path.endsWith('kundli')) {
                return http.Response(
                  jsonEncode({
                    'sandbox': false,
                    'chartTicket': 'TEST-ONLY-ticket',
                    'profileId': 'test-profile',
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
              }
              if (jsonDecode(request.body)['question'] ==
                  'Show the selected profile rasi, nakshatra and current Saturn status.') {
                return http.Response(
                  jsonEncode({
                    'profileId': 'test-profile',
                    'answer': 'Your rasi is Meena.',
                    'answerMode': 'chart_guidance',
                    'evidence': [],
                  }),
                  200,
                );
              }
              questionCalls++;
              final body = jsonDecode(request.body);
              expect(body['responseStyle'], entry.key);
              expect(body['profileId'], 'test-profile');
              expect(body['chartTicket'], 'TEST-ONLY-ticket');
              expect(body.containsKey('chart'), false);
              expect(body['researchConsent'], false);
              return http.Response(
                jsonEncode({
                  'profileId': 'test-profile',
                  'answer': 'Provider test response',
                  'evidence': ['Rashi: Meena'],
                  'answerMode': 'personalised',
                }),
                200,
              );
            }),
          ),
        );
        await session.calculate(
          dateTime: '2000-01-01T05:00:00+05:30',
          latitude: 11,
          longitude: 77,
          exactTime: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(guide: guides[1], session: session),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('chatInput')), entry.value);
        await tester.tap(find.byKey(const Key('sendMessage')));
        await tester.pumpAndSettle();
        expect(questionCalls, 1);
        expect(find.textContaining('Provider test response'), findsOneWidget);
        expect(find.textContaining('Rashi: Meena'), findsOneWidget);
        expect(find.textContaining('PREVIEW RESPONSE'), findsNothing);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(guide: guides[1], session: session),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Provider test response'), findsOneWidget);
        expect(
          questionCalls,
          1,
          reason: 'Reopening history must not repeat paid requests',
        );
        session.clear();
        await tester.pumpAndSettle();
        expect(find.textContaining('Provider test response'), findsNothing);
      },
    );
  }

  testWidgets('missing profile never fabricates an answer', (tester) async {
    var calls = 0;
    final session = ProfileSession(
      api: JyotaraApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(guide: guides[0], session: session),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('chatInput')),
      'Will they marry me?',
    );
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.textContaining('Create your birth chart before'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Will they marry me?'),
      findsOneWidget,
    );
  });
}
