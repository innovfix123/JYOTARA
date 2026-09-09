import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/profile_gender.dart';

void main() {
  test('report birth details are frozen with the question for a safe retry', () async {
    final sent = <Map<String, dynamic>>[];
    final session = ProfileSession(api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) return http.Response(jsonEncode({
        'sandbox': false, 'chartTicket': 'test-ticket', 'profileId': 'test-profile',
        'result': {'data': {'nakshatra_details': {'chandra_rasi': {'name': 'Meena'}, 'nakshatra': {'name': 'Revati'}}}},
      }), 200);
      sent.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"profileId":"test-profile","answer":"Test response","evidence":[]}', 200);
    })));
    await session.calculate(dateTime: '2000-01-01T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true, nickname: 'Synthetic', gender: ProfileGender.male, birthplaceLabel: 'Test city');
    await session.ask(category: 'Marriage', question: 'When will I marry?', responseStyle: 'english');
    session.nickname = 'Changed';
    await session.ask(category: 'Marriage', question: 'When will I marry?', responseStyle: 'english');
    expect(sent.length, 2);
    expect(sent.first['reportPerson']['name'], 'Synthetic');
    expect(sent.last['reportPerson'], sent.first['reportPerson']);
    expect(sent.last['requestId'], sent.first['requestId']);
    session.dispose();
  });

  test(
    'clock rollback is rejected; 24-hour expiry renews without natal recalculation',
    () async {
      var now = DateTime.utc(2026, 9, 6, 10);
      var charts = 0;
      var questions = 0;
      var renewals = 0;
      final session = ProfileSession(
        clock: () => now,
        api: JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('kundli')) {
              charts++;
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
            if (request.url.path.endsWith('/renew')) {
              renewals++;
              return http.Response(jsonEncode({'profileId': 'test-profile', 'chartTicket': 'TEST-renewed',
                'renewed': true, 'natalRecalculated': false, 'chatAuthorizedAt': now.toIso8601String(),
                'chatExpiresAt': now.add(const Duration(hours: 24)).toIso8601String()}), 200);
            }
            questions++;
            return http.Response(
              '{"profileId":"test-profile","answer":"Test response","evidence":[]}',
              200,
            );
          }),
        ),
      );
      Future<void> calculate() => session.calculate(
        dateTime: '2000-01-01T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      Future<GuidanceResponse> ask() => session.ask(
        category: 'Career',
        question: 'Job?',
        responseStyle: 'english',
      );
      await calculate();
      now = now.subtract(const Duration(microseconds: 1));
      await expectLater(ask(), throwsA(isA<JyotaraApiException>()));
      expect(questions, 0);
      await expectLater(calculate(), throwsA(isA<JyotaraApiException>()));
      expect(charts, 1, reason: 'Clock rollback must not cause a paid recalculation');
      expect(renewals, 0);
      now = DateTime.utc(2026, 9, 6, 10)
          .add(const Duration(hours: 24))
          .subtract(const Duration(microseconds: 1));
      await calculate();
      expect(charts, 1);
      await ask();
      expect(questions, 1);
      now = now.add(const Duration(microseconds: 1));
      await ask();
      expect(questions, 2);
      expect(renewals, 1);
      await calculate();
      expect(charts, 1);
    },
  );
  test('old profile completion cannot unlock a new pending answer', () async {
    final replies = <Completer<http.Response>>[];
    final session = ProfileSession(
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
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
          final reply = Completer<http.Response>();
          replies.add(reply);
          return reply.future;
        }),
      ),
    );
    Future<void> calculate() => session.calculate(
      dateTime: '2000-01-01T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    Future<GuidanceResponse> ask() => session.ask(
      category: 'Career',
      question: 'Job?',
      responseStyle: 'english',
    );
    await calculate();
    final old = ask();
    final rejectedOld = expectLater(old, throwsA(isA<JyotaraApiException>()));
    await Future<void>.delayed(Duration.zero);
    await session.clear();
    expect(session.answering, false);
    await calculate();
    final current = ask();
    await Future<void>.delayed(Duration.zero);
    expect(replies.length, 2);
    replies.first.complete(
      http.Response('{"profileId":"test-profile","answer":"Old answer","evidence":[]}', 200),
    );
    await rejectedOld;
    expect(session.answering, true);
    await expectLater(ask(), throwsA(isA<JyotaraApiException>()));
    expect(replies.length, 2);
    replies.last.complete(
      http.Response(
        '{"profileId":"test-profile","answer":"Current answer","evidence":[]}',
        200,
      ),
    );
    expect((await current).answer, 'Current answer');
    expect(session.answering, false);
  });
  test('guide conversations retain language but never cross session/profile clearing', () {
    final session = ProfileSession();
    final first = session.conversation('Arivan');
    first.messages.add(
      const ChatMessage(fromUser: true, text: 'Career question'),
    );
    first.language = 'english';
    expect(identical(first, session.conversation('Arivan')), true);
    expect(
      session.conversation('Arivan').messages.single.text,
      'Career question',
    );
    expect(session.conversation('Arivan').language, 'english');
    expect(session.conversation('Aadhirai').messages, isEmpty);
    expect(ProfileSession().conversation('Arivan').messages, isEmpty);
    session.clear();
    expect(
      first.messages,
      isEmpty,
      reason: 'Also wipe references held by old screens',
    );
    expect(first.language, 'auto');
    expect(session.conversation('Arivan').messages, isEmpty);
  });
  test(
    'calculated provider identity reaches guidance and clearing blocks reuse',
    () async {
      var calls = 0;
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
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
          final body = jsonDecode(request.body);
          expect(body['profileId'], 'test-profile');
          expect(body['chartTicket'], 'TEST-ONLY-ticket');
          expect(body.containsKey('chart'), false);
          expect(body.containsKey('birthTimeKnown'), false);
          return http.Response(
            jsonEncode({
              'profileId': 'test-profile',
              'answer': 'A test answer.',
              'evidence': ['Rashi: Meena'],
            }),
            200,
          );
        }),
      );
      final session = ProfileSession(api: api);
      await expectLater(
        session.ask(
          category: 'Career',
          question: 'Job?',
          responseStyle: 'english',
        ),
        throwsA(isA<JyotaraApiException>()),
      );
      expect(calls, 0);
      await session.calculate(
        dateTime: '2000-01-01T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      final exposed = session.facts!;
      expect(() => exposed['rashi'] = 'Mesha', throwsUnsupportedError);
      expect(
        () => (exposed['planets'] as List).add({'name': 'Invented'}),
        throwsUnsupportedError,
      );
      expect(() => (exposed['yogas'] as List).clear(), throwsUnsupportedError);
      final answer = await session.ask(
        category: 'Career',
        question: 'Job?',
        responseStyle: 'english',
      );
      expect(answer.answer, 'A test answer.');
      expect(calls, 2);
      await session.calculate(
        dateTime: '2000-01-01T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      expect(
        calls,
        2,
        reason: 'Identical confirmed profile must not spend again within the cache window.',
      );
      session.clear();
      expect(session.facts, null);
      await expectLater(
        session.ask(
          category: 'Career',
          question: 'Job?',
          responseStyle: 'english',
        ),
        throwsA(isA<JyotaraApiException>()),
      );
      expect(calls, 2);
    },
  );
}
