import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test(
    'malformed guidance never becomes a blank or partly filtered answer',
    () async {
      final valid = <String, dynamic>{
        'profileId': 'profile',
        'answer': 'A complete answer',
        'evidence': ['Moon: Meena'],
        'support': 'partially_supported',
        'answerMode': 'grounded_fallback',
      };
      for (final patch in <Map<String, dynamic>>[
        {'answer': ''},
        {'answer': '   '},
        {'answer': null},
        {'answer': 1},
        {'answer': 'a' * 20001},
        {'evidence': null},
        {'evidence': 'Moon'},
        {
          'evidence': ['Moon', 123],
        },
        {
          'evidence': [''],
        },
        {'evidence': List.filled(101, 'Moon')},
        {
          'evidence': ['a' * 2001],
        },
        {'limitation': []},
        {'support': {}},
        {'answerMode': false},
      ]) {
        var calls = 0;
        final api = JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((_) async {
            calls++;
            return http.Response(jsonEncode({...valid, ...patch}), 200);
          }),
        );
        await expectLater(
          api.askGuidance(
            category: 'Career',
            question: 'Career?',
            responseStyle: 'english',
            birthTimeKnown: true,
            chart: {},
            chartTicket: 'ticket',
            profileId: 'profile',
          ),
          throwsA(
            isA<JyotaraApiException>().having(
              (e) => e.deliveryUncertain,
              'uncertain delivery',
              true,
            ),
          ),
        );
        expect(
          calls,
          1,
          reason: 'Invalid replies must not trigger automatic retries',
        );
        api.close();
      }
      final response = GuidanceResponse.fromJson(valid);
      expect(response.answer, 'A complete answer');
      expect(() => response.evidence.add('Invented'), throwsUnsupportedError);
    },
  );

  test('unknown delivery and malformed server errors remain typed without automatic retries', () async {
    for (final mode in ['connection', 'html', 'object-error']) {
      var calls = 0;
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          calls++;
          if (mode == 'connection') throw http.ClientException('closed');
          return mode == 'html'
              ? http.Response('<html>Error</html>', 502)
              : http.Response('{"error":{"private":"details"}}', 500);
        }),
      );
      try {
        await api.searchLocations('Erode');
        fail('Expected typed error');
      } on JyotaraApiException catch (error) {
        expect(error.deliveryUncertain, true);
        expect(error.chatLabel, 'ANSWER NOT CONFIRMED');
        expect(error.chatMessage, contains('may have reached the server'));
        expect(error.chatMessage, isNot(contains('private')));
      }
      expect(calls, 1);
      api.close();
    }
  });
  test(
    'invalid birth dates and context timestamps never reach transport',
    () async {
      var calls = 0;
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          return http.Response('{"sandbox":false}', 200);
        }),
      );
      for (final value in [
        '2002-02-30T05:00:00+05:30',
        '2002-07-29T25:00:00+05:30',
        '2002-07-29T05:00:00+05:99',
        '2002-07-29T05:00:00',
      ]) {
        await expectLater(
          api.calculateChart(
            dateTime: value,
            latitude: 11,
            longitude: 77,
            currentDateTime: '2026-09-07T00:00:00Z',
          ),
          throwsA(isA<JyotaraApiException>()),
        );
      }
      await expectLater(
        api.calculateChart(
          dateTime: '2002-07-29T05:00:00+05:30',
          latitude: 11,
          longitude: 77,
          currentDateTime: '2026-02-30T00:00:00Z',
        ),
        throwsA(isA<JyotaraApiException>()),
      );
      expect(calls, 0);
      await api.calculateChart(
        dateTime: '2004-02-29T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        currentDateTime: '2026-09-07T00:00:00Z',
      );
      expect(calls, 1);
    },
  );
  test('guidance rejects absent ticket before transport and mismatched reply identity', () async {
    var calls = 0;
    final api = JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calls++;
        return http.Response(
          '{"profileId":"different-profile","answer":"Must not display"}',
          200,
        );
      }),
    );
    Future<GuidanceResponse> ask({String? ticket, String? profile}) =>
        api.askGuidance(
          category: 'Career',
          question: 'Job?',
          responseStyle: 'english',
          birthTimeKnown: true,
          chart: const {},
          chartTicket: ticket,
          profileId: profile,
        );
    await expectLater(ask(), throwsA(isA<JyotaraApiException>()));
    expect(calls, 0);
    await expectLater(
      ask(ticket: 'test-ticket', profile: 'expected-profile'),
      throwsA(isA<JyotaraApiException>()),
    );
    expect(calls, 1);
  });
  test(
    'chart request uses protected backend and preserves its session',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'sandbox': false,
            'chartTicket': 'TEST-ONLY-ticket',
            'profileId': 'test-profile',
            'result': {'nakshatra': 'Example'},
            'moduleStatus': {'kundli': 'connected'},
          }),
          200,
          headers: {
            'set-cookie': 'nirayana_pilot_session=session-test; Path=/',
          },
        );
      });
      final api = JyotaraApiClient(
        client: client,
        baseUrl: 'https://example.test',
      );

      final result = await api.calculateChart(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11.3410,
        longitude: 77.7172,
        currentDateTime: '2026-09-05T12:00:00+05:30',
      );
      await api.calculateChart(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11.3410,
        longitude: 77.7172,
        currentDateTime: '2026-09-05T12:00:00+05:30',
      );

      expect(result.sandbox, isFalse);
      expect(result.moduleStatus['kundli'], 'connected');
      expect(requests.first.url.path, '/api/astrology/kundli');
      expect(requests.first.headers.containsKey('Authorization'), isFalse);
      expect(
        requests.last.headers['Cookie'],
        'nirayana_pilot_session=session-test',
      );
    },
  );

  test(
    'Tanglish is represented as a response style without an app key',
    () async {
      late Map<String, dynamic> sentBody;
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'profileId': 'test-profile',
              'answer': 'Unga kelvi purinjiduchu.',
              'evidence': ['Rashi: Example'],
              'support': 'partial',
              'answerMode': 'personalised',
            }),
            200,
          );
        }),
      );

      final response = await api.askGuidance(
        category: 'Career',
        question: 'Enaku job change panna nalla time ah?',
        responseStyle: 'tanglish',
        birthTimeKnown: true,
        chart: const {'rashi': 'Example'},
        chartTicket: 'TEST-ONLY-ticket',
        profileId: 'test-profile',
      );

      expect(sentBody['language'], 'ta');
      expect(sentBody['responseStyle'], 'tanglish');
      expect(sentBody.containsKey('apiKey'), isFalse);
      expect(response.answer, 'Unga kelvi purinjiduchu.');
    },
  );

  test('server errors become typed API exceptions', () async {
    final api = JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'error': 'Limit reached'}), 429),
      ),
    );

    expect(
      () => api.calculateChart(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11.3410,
        longitude: 77.7172,
        currentDateTime: '2026-09-05T12:00:00+05:30',
      ),
      throwsA(
        isA<JyotaraApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          429,
        ),
      ),
    );
  });
}
