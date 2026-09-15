import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test(
    'report sends only selected answer with authentication and consent',
    () async {
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        phoneToken: () => 'test-token',
        client: MockClient((request) async {
          expect(request.url.path, '/api/answers/report');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(jsonDecode(request.body), {
            'answer': 'Selected answer',
            'guide': 'Guide',
            'reason': 'harmful',
            'consent': true,
          });
          return http.Response('{"reported":true}', 200);
        }),
      );
      await api.reportAnswer(
        answer: 'Selected answer',
        guide: 'Guide',
        reason: 'harmful',
      );
    },
  );
  test('missing acknowledgement is not reported as success', () async {
    final api = JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      api.reportAnswer(answer: 'Answer', guide: 'Guide', reason: 'other'),
      throwsA(isA<JyotaraApiException>()),
    );
  });
}
