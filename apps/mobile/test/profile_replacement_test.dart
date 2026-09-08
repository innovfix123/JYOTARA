import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';

http.Response chartReply(String id, {bool malformed = false}) => http.Response(
  jsonEncode({
    'sandbox': false,
    'chartTicket': 'ticket-$id',
    'profileId': id,
    if (!malformed)
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
  headers: {'set-cookie': 'nirayana_pilot_session=$id; HttpOnly'},
);

void main() {
  test('failed replacement preserves profile, cookie and persisted history; valid replacement clears old history', () async {
    String? disk;
    final vault = LocalProfileVault(
      read: () async => disk,
      write: (value) async {
        disk = value;
      },
    );
    final replacement = Completer<http.Response>();
    var calls = 0;
    final api = JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return chartReply('original');
        if (calls == 2) return replacement.future;
        return chartReply('replacement');
      }),
    );
    final session = ProfileSession(api: api, vault: vault);
    Future<void> calculate(String date) => session.calculate(
      dateTime: '${date}T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    await calculate('2002-07-29');
    final chat = session.conversation('Arivan');
    chat.messages.add(
      const ChatMessage(fromUser: true, text: 'Original question'),
    );
    chat.changed();
    session.setResearchConsent(true);
    await session.flushStorage();
    final originalDisk = disk;
    final originalFacts = session.facts;
    final changing = calculate('2002-07-30');
    final failure = expectLater(changing, throwsA(isA<Exception>()));
    expect(session.calculating, true);
    expect(session.facts, originalFacts);
    await expectLater(
      session.ask(
        category: 'Career',
        question: 'New question',
        responseStyle: 'english',
      ),
      throwsA(isA<JyotaraApiException>()),
    );
    await Future<void>.delayed(Duration.zero);
    replacement.complete(chartReply('bad-session', malformed: true));
    await failure;
    expect(session.calculating, false);
    expect(session.facts, originalFacts);
    expect(api.sessionForStorage, 'nirayana_pilot_session=original');
    expect(
      session.conversation('Arivan').messages.single.text,
      'Original question',
    );
    expect(session.researchConsent, true);
    expect(disk, originalDisk);
    await calculate('2002-07-30');
    await session.flushStorage();
    expect(session.conversation('Arivan').messages, isEmpty);
    expect(session.researchConsent, false);
    expect(api.sessionForStorage, 'nirayana_pilot_session=replacement');
    expect(disk, isNot(originalDisk));
    expect(calls, 3, reason: 'No hidden calculation retry or guidance request');
  });

  test('renewing the same birth details retains chat history without recalculation', () async {
    var now = DateTime.utc(2026, 9, 7);
    var calls = 0;
    final session = ProfileSession(
      clock: () => now,
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          if (calls == 2) {
            expect(request.url.path, '/api/profile/renew');
            return http.Response(jsonEncode({'profileId': 'same-profile', 'chartTicket': 'renewed-same-profile',
              'renewed': true, 'natalRecalculated': false, 'chatAuthorizedAt': now.toIso8601String(),
              'chatExpiresAt': now.add(const Duration(hours: 24)).toIso8601String()}), 200);
          }
          return chartReply('same-profile');
        }),
      ),
    );
    Future<void> calculate() => session.calculate(
      dateTime: '2002-07-29T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    await calculate();
    session
        .conversation('Arivan')
        .messages
        .add(
          const ChatMessage(fromUser: true, text: 'Keep historical question'),
        );
    now = now.add(const Duration(hours: 24));
    await calculate();
    expect(calls, 2);
    expect(
      session.conversation('Arivan').messages.single.text,
      'Keep historical question',
    );
  });
}
