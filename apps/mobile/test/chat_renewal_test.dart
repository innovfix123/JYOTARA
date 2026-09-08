import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'profile_replacement_test.dart' show chartReply;

void main() {
  test('invalid questions do not renew expired access or contact guidance', () async {
    var now = DateTime.utc(2026, 9, 7);
    var calls = 0;
    final session = ProfileSession(clock: () => now, api: JyotaraApiClient(
      baseUrl: 'https://example.test', client: MockClient((request) async {
        calls++;
        expect(request.url.path.endsWith('kundli'), true);
        return chartReply('saved');
      }),
    ));
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    now = now.add(const Duration(days: 2));
    for (final question in ['   ', List.filled(241, 'a').join()]) {
      await expectLater(session.ask(category: 'Career', question: question, responseStyle: 'english'),
        throwsA(isA<JyotaraApiException>().having((e) => e.toString(), 'message', contains('240 characters'))));
    }
    expect(calls, 1);
    expect(session.answering, false);
  });

  test('late renewal cannot restore a cleared profile', () async {
    var now = DateTime.utc(2026, 9, 7);
    final reply = Completer<http.Response>();
    final session = ProfileSession(clock: () => now, api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) return chartReply('saved');
      return reply.future;
    })));
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    now = now.add(const Duration(days: 2));
    final pending = session.renewChatAccess();
    final failure = expectLater(pending, throwsA(isA<JyotaraApiException>()));
    await session.clear();
    reply.complete(http.Response(jsonEncode({'profileId': 'saved', 'chartTicket': 'late-ticket',
      'renewed': true, 'natalRecalculated': false, 'chatAuthorizedAt': now.toIso8601String(),
      'chatExpiresAt': now.add(const Duration(hours: 24)).toIso8601String()}), 200));
    await failure;
    expect(session.facts, null);
    expect(session.canDeleteServer, false);
    expect(session.calculatedAt, null);
  });

  test('renewal coalesces, preserves natal date, and survives restart without a paid chart request', () async {
    var now = DateTime.utc(2026, 9, 7);
    String? disk;
    var natal = 0, renewals = 0, questions = 0;
    final wait = Completer<http.Response>();
    final vault = LocalProfileVault(read: () async => disk, write: (v) async => disk = v);
    JyotaraApiClient client() => JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) { natal++; return chartReply('saved'); }
      if (request.url.path.endsWith('/renew')) { renewals++; return wait.future; }
      questions++;
      expect(jsonDecode(request.body)['chartTicket'], 'renewed-ticket');
      return http.Response('{"profileId":"saved","answer":"Synthetic response","evidence":[]}', 200);
    }));
    final session = ProfileSession(api: client(), clock: () => now, vault: vault);
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await session.flushStorage();
    final birthCalculation = session.calculatedAt;
    now = now.add(const Duration(days: 2));
    final first = session.renewChatAccess();
    expect(identical(first, session.renewChatAccess()), true);
    wait.complete(http.Response(jsonEncode({'profileId': 'saved', 'chartTicket': 'renewed-ticket',
      'renewed': true, 'natalRecalculated': false, 'chatAuthorizedAt': now.toIso8601String(),
      'chatExpiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
      'chart': {'rashi': 'DO NOT IMPORT'}, 'chartCalculatedAt': now.toIso8601String()}), 200));
    await first;
    expect(session.calculatedAt, birthCalculation);
    expect(session.facts.toString(), isNot(contains('DO NOT IMPORT')));
    final restored = ProfileSession(api: client(), clock: () => now, vault: vault);
    await restored.restore();
    expect(restored.calculatedAt, birthCalculation);
    await restored.ask(category: 'Career', question: 'Which career?', responseStyle: 'english');
    expect(natal, 1);
    expect(renewals, 1);
    expect(questions, 1);
  });

  test('renewal rejection never automatically generates a replacement natal chart', () async {
    var now = DateTime.utc(2026, 9, 7);
    var natal = 0, questions = 0;
    final session = ProfileSession(clock: () => now, api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) { natal++; return chartReply('saved'); }
      if (request.url.path.endsWith('/renew')) return http.Response('{"error":"Renewal window expired"}', 401);
      questions++;
      throw StateError('No guidance expected');
    })));
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    final original = session.calculatedAt;
    now = now.add(const Duration(days: 31));
    await expectLater(session.ask(category: 'Career', question: 'Job?', responseStyle: 'english'), throwsA(isA<JyotaraApiException>()));
    expect(natal, 1);
    expect(questions, 0);
    expect(session.calculatedAt, original);
    expect(session.facts, isNotNull);
  });
}
