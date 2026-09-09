import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/jyotara_api.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  test('explicit calculation refreshes expired chart and preserves same-person history', () async {
    var now = DateTime.utc(2026, 9, 7);
    var charts = 0;
    final session = ProfileSession(
      clock: () => now,
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((r) async {
          if (r.url.path.endsWith('kundli')) {
            charts++;
            return chartReply('saved');
          }
          return http.Response(
            jsonEncode({
              'error': 'Refresh needed',
              'code': 'provider_refresh_required',
            }),
            409,
          );
        }),
      ),
    );
    Future<void> calculate() => session.calculate(
      dateTime: '2002-07-29T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
      nickname: 'Saran',
    );
    await calculate();
    session
        .conversation('Arul')
        .messages
        .add(const ChatMessage(fromUser: true, text: 'Keep this conversation'));
    now = now.add(const Duration(days: 2));
    await expectLater(
      session.ask(
        category: 'Daily',
        question: 'Hello chart',
        responseStyle: 'english',
      ),
      throwsA(isA<JyotaraApiException>()),
    );
    expect(
      charts,
      1,
      reason: 'Ordinary chat must not silently buy a fresh chart',
    );
    await calculate();
    expect(charts, 2);
    expect(session.nickname, 'Saran');
    expect(
      session.conversation('Arul').messages.single.text,
      'Keep this conversation',
    );
  });
}
