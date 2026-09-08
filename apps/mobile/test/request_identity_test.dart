import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'profile_replacement_test.dart' show chartReply;

void main() {
  test('uncertain delivery reuses persisted identity after restart without automatic resend', () async {
    String? disk;
    final sent = <Map<String, dynamic>>[];
    final vault = LocalProfileVault(read: () async => disk, write: (value) async => disk = value);
    ProfileSession session() => ProfileSession(vault: vault, api: JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('kundli')) return chartReply('one');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        sent.add(payload);
        final saved = jsonDecode(disk!) as Map<String, dynamic>;
        expect((saved['requestIds'] as Map).values, contains(payload['requestId']),
          reason: 'Recovery identity must reach storage before transport');
        if (sent.length == 1) throw http.ClientException('Synthetic dropped response');
        return http.Response('{"profileId":"one","answer":"Synthetic recovered answer","evidence":[]}', 200);
      }),
    ));
    final first = session();
    await first.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await expectLater(first.ask(category: 'Career', question: 'Job change?', responseStyle: 'english'), throwsA(isA<JyotaraApiException>()));
    final restored = session();
    await restored.restore();
    expect(sent, hasLength(1), reason: 'Restore must not automatically resubmit');
    final recovered = await restored.ask(category: 'Career', question: 'Job   change?', responseStyle: 'english');
    expect(sent[0]['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(sent[1]['requestId'], sent[0]['requestId']);
    final chat = restored.conversation('Arivan');
    expect(await restored.recordGuidanceResponse(recovered, chat, 'english'), true);
    expect(await restored.recordGuidanceResponse(recovered, chat, 'english'), false,
      reason: 'A completion callback must not append the same answer twice');
    final committed = jsonDecode(disk!) as Map<String, dynamic>;
    expect((committed['requestIds'] as Map).values, isNot(contains(sent[0]['requestId'])));
    expect(chat.messages, hasLength(1));
    final reopened = session();
    await reopened.restore();
    expect(reopened.conversation('Arivan').messages.single.text, contains('Synthetic recovered answer'));
    await reopened.ask(category: 'Career', question: 'Job change?', responseStyle: 'english');
    expect(sent[2]['requestId'], isNot(sent[0]['requestId']),
      reason: 'A new question after durable completion gets a fresh identity');
    await restored.ask(category: 'Career', question: 'Promotion?', responseStyle: 'english');
    expect(sent[3]['requestId'], isNot(sent[0]['requestId']));
  });

  test('failed recovery-record save prevents guidance transport', () async {
    var failWrites = false;
    var questions = 0;
    final session = ProfileSession(
      vault: LocalProfileVault(write: (_) async { if (failWrites) throw StateError('Synthetic storage failure'); }),
      api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
        if (request.url.path.endsWith('kundli')) return chartReply('one');
        questions++;
        throw StateError('Must not send');
      })),
    );
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await session.flushStorage();
    failWrites = true;
    await expectLater(session.ask(category: 'Career', question: 'Job?', responseStyle: 'english'), throwsA(isA<JyotaraApiException>()));
    expect(questions, 0);
    expect(session.answering, false);
    expect(session.storageError, isNotNull);
  });

  test('received but uncommitted answer and failed completion save retain retry identity', () async {
    String? disk;
    var failWrites = false;
    final sent = <String>[];
    final vault = LocalProfileVault(read: () async => disk, write: (value) async {
      if (failWrites) throw StateError('Synthetic completion save failure');
      disk = value;
    });
    ProfileSession make() => ProfileSession(vault: vault, api: JyotaraApiClient(
      baseUrl: 'https://example.test', client: MockClient((request) async {
        if (request.url.path.endsWith('kundli')) return chartReply('one');
        sent.add(jsonDecode(request.body)['requestId'] as String);
        return http.Response('{"profileId":"one","answer":"Synthetic answer","evidence":[]}', 200);
      }),
    ));
    final first = make();
    await first.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await first.ask(category: 'Career', question: 'Career support?', responseStyle: 'english');
    // Simulate closing after HTTP success but before history commit.
    final restored = make();
    await restored.restore();
    final result = await restored.ask(category: 'Career', question: 'Career support?', responseStyle: 'english');
    expect(sent[1], sent[0]);
    failWrites = true;
    await restored.recordGuidanceResponse(result, restored.conversation('Arivan'), 'english');
    expect(restored.storageError, isNotNull);
    expect((jsonDecode(disk!)['requestIds'] as Map).values, contains(sent[0]));
    failWrites = false;
    await restored.ask(category: 'Career', question: 'Career support?', responseStyle: 'english');
    expect(sent[2], sent[0], reason: 'Failed history save cannot silently allocate a fresh billable request');
  });
}
