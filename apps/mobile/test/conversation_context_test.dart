import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  test(
    'bounded guide context survives retry and restart, and clears with profile',
    () async {
      String? disk;
      bool fail = true;
      final sent = <Map<String, dynamic>>[];
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (v) async => disk = v,
      );
      ProfileSession make() => ProfileSession(
        vault: vault,
        api: JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('kundli')) return chartReply('one');
            sent.add(jsonDecode(request.body) as Map<String, dynamic>);
            if (fail) {
              throw http.ClientException('Synthetic interrupted delivery');
            }
            return http.Response(
              '{"profileId":"one","answer":"Practical response","evidence":[],"answerMode":"practical_guidance"}',
              200,
            );
          }),
        ),
      );
      var session = make();
      await session.calculate(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      final chat = session.conversation('Aadhirai');
      for (var i = 0; i < 8; i++) {
        chat.messages.add(
          ChatMessage(fromUser: true, text: 'Prior statement $i'),
        );
        chat.messages.add(
          const ChatMessage(
            fromUser: false,
            text: 'Old unverified assistant claim',
          ),
        );
      }
      chat.messages.add(
        const ChatMessage(fromUser: true, text: 'Another chance?'),
      );
      chat.pending = true;
      chat.changed();
      session
          .conversation('Arivan')
          .messages
          .add(
            const ChatMessage(fromUser: true, text: 'Private career question'),
          );
      Future<GuidanceResponse> ask(
        ProfileSession value, [
        String guide = 'Aadhirai',
      ]) => value.ask(
        category: 'Love',
        question: 'Another chance?',
        responseStyle: 'english',
        guide: guide,
      );
      await expectLater(ask(session), throwsA(isA<JyotaraApiException>()));
      expect(
        sent.single['previousUserMessages'],
        List.generate(6, (i) => 'Prior statement ${i + 2}'),
      );
      expect(sent.single['conversationHistory'], hasLength(12));
      expect(
        jsonEncode(sent.single['conversationHistory']),
        contains('Old unverified assistant claim'),
      );
      expect(
        (sent.single['conversationHistory'] as List).last['role'],
        'assistant',
      );
      expect(jsonEncode(sent.single), isNot(contains('Private career')));
      session = make();
      await session.restore();
      expect(sent, hasLength(1), reason: 'Restoring does not resubmit');
      session
          .conversation('Aadhirai')
          .messages
          .add(
            const ChatMessage(
              fromUser: true,
              text: 'New statement after uncertain send',
            ),
          );
      fail = false;
      final reply = await ask(session);
      expect(sent[1]['requestId'], sent[0]['requestId']);
      expect(sent[1]['previousUserMessages'], sent[0]['previousUserMessages']);
      expect(sent[1]['conversationHistory'], sent[0]['conversationHistory']);
      await session.recordGuidanceResponse(
        reply,
        session.conversation('Aadhirai'),
        'english',
      );
      expect((jsonDecode(disk!)['requestContexts'] as Map), isEmpty);
      expect((jsonDecode(disk!)['conversationContexts'] as Map), isEmpty);
      await ask(session, 'Arivan');
      expect(sent[2]['requestId'], isNot(sent[0]['requestId']));
      expect(sent[2]['previousUserMessages'], ['Private career question']);
      await session.clear();
      await session.calculate(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      await ask(session);
      expect(sent.last['previousUserMessages'], isNull);
      expect(sent.last['requestId'], isNot(sent[0]['requestId']));
    },
  );
}
