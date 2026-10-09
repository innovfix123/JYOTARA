import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  test('a saved price schedule cannot silently authorize higher prices or another account', () {
    const consent = CoinChatConsent(
      'owner',
      'standard',
      12,
      generalCoins: 8,
      relationshipCoins: 12,
    );
    const payload = {'depth': 'standard'};
    Map<String, dynamic> quote(String category, int cost) => {
      'category': category,
      'cost': cost,
      'depth': 'standard',
      'canProceed': true,
    };
    expect(consent.accepts('owner', payload, quote('Career', 8)), isTrue);
    expect(consent.accepts('owner', payload, quote('Love', 12)), isTrue);
    expect(consent.accepts('owner', payload, quote('Career', 10)), isFalse);
    expect(consent.accepts('owner', payload, quote('Love', 15)), isFalse);
    expect(
      consent.accepts('another-account', payload, quote('Career', 8)),
      isFalse,
    );
    expect(consent.accepts('owner', payload, quote('Career', 0)), isTrue);
  });

  test('accepted prices persist exactly and legacy or invalid consent records require fresh disclosure', () async {
    String? stored;
    ProfileSession create() => ProfileSession(
      vault: LocalProfileVault(
        read: () async => stored,
        write: (value) async => stored = value,
      ),
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'sandbox': false,
              'chartTicket': 'test-ticket',
              'profileId': 'test-profile',
              'result': {
                'data': {
                  'nakshatra_details': {
                    'chandra_rasi': {'name': 'Meena'},
                    'nakshatra': {'name': 'Revati'},
                  },
                },
              },
            }),
            200,
          ),
        ),
      ),
    );
    final original = create();
    await original.calculate(
      dateTime: '2000-01-01T12:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: false,
    );
    await original.flushStorage();
    original.conversation('Vetri')
      ..depth = 'standard'
      ..billingSession = 'a' * 32
      ..billingAcknowledged = true
      ..acceptedGeneralCoins = 8
      ..acceptedRelationshipCoins = 12
      ..changed();
    await original.flushStorage();
    original.dispose();
    final saved = stored!;
    final restored = create();
    await restored.restore();
    final chat = restored.conversation('Vetri');
    expect(chat.billingAcknowledged, isTrue);
    expect(chat.billingSession, 'a' * 32);
    expect(chat.acceptedGeneralCoins, 8);
    expect(chat.acceptedRelationshipCoins, 12);
    restored.startNewConversation('Vetri');
    expect(chat.billingAcknowledged, isFalse);
    expect(chat.billingSession, isNull);
    expect(chat.acceptedGeneralCoins, isNull);
    expect(chat.acceptedRelationshipCoins, isNull);
    await restored.flushStorage();
    restored.dispose();
    for (final invalid in [null, -1, 501, '8']) {
      final record = jsonDecode(saved) as Map<String, dynamic>;
      final oldChat = record['conversations']['Vetri'] as Map<String, dynamic>;
      oldChat['acceptedGeneralCoins'] = invalid;
      if (invalid == null) oldChat.remove('acceptedRelationshipCoins');
      stored = jsonEncode(record);
      final legacy = create();
      await legacy.restore();
      expect(legacy.storageError, isNull);
      expect(
        legacy.conversation('Vetri').billingAcknowledged,
        isFalse,
        reason: 'Unverified accepted amounts must never become automatic paid consent',
      );
      await legacy.flushStorage();
      legacy.dispose();
    }
  });

  test('conversation context and earlier user memory stay frozen across a manual retry after restart', () async {
    String? stored;
    final sent = <Map<String, dynamic>>[];
    var failAnswer = true;
    ProfileSession create() => ProfileSession(
      vault: LocalProfileVault(
        read: () async => stored,
        write: (value) async => stored = value,
      ),
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('kundli')) {
            return http.Response(
              jsonEncode({
                'sandbox': false,
                'chartTicket': 'test-ticket',
                'profileId': 'test-profile',
                'result': {
                  'data': {
                    'nakshatra_details': {
                      'chandra_rasi': {'name': 'Meena'},
                      'nakshatra': {'name': 'Revati'},
                    },
                  },
                },
              }),
              200,
            );
          }
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (failAnswer) {
            throw http.ClientException('Synthetic uncertain delivery');
          }
          return http.Response(
            '{"profileId":"test-profile","answer":"A useful answer.","answerMode":"limited_guidance","evidence":[]}',
            200,
          );
        }),
      ),
    );
    final original = create();
    await original.calculate(
      dateTime: '2000-01-01T12:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: false,
    );
    final chat = original.conversation('Vetri');
    for (var i = 0; i < 44; i++) {
      chat.messages.add(
        ChatMessage(fromUser: true, text: 'User statement $i.'),
      );
      chat.messages.add(
        ChatMessage(fromUser: false, text: 'Assistant reply $i.'),
      );
    }
    const question = 'How can I prepare for interviews?';
    chat.messages.add(const ChatMessage(fromUser: true, text: question));
    chat.changed();
    var billingSession = 'b' * 32;
    Future<GuidanceResponse> ask(ProfileSession session) => session.ask(
      category: 'Career',
      question: question,
      responseStyle: 'english',
      guide: 'Vetri',
      depth: 'standard',
      billingSession: billingSession,
    );
    await expectLater(ask(original), throwsA(isA<JyotaraApiException>()));
    expect(
      sent,
      hasLength(1),
      reason: 'Uncertain delivery must not auto-resubmit a paid request',
    );
    expect(sent.single['responseMode'], 'conversation');
    expect(sent.single['billingVersion'], 2);
    expect(sent.single['billingSession'], 'b' * 32);
    expect(sent.single['conversationHistory'], hasLength(32));
    expect(sent.single['conversationHistory'].first, {
      'role': 'user',
      'content': 'User statement 28.',
    });
    expect(
      sent.single['conversationMemory'],
      List.generate(12, (i) => 'User statement ${i + 16}.'),
    );
    chat.messages.add(
      const ChatMessage(
        fromUser: true,
        text: 'A later correction must not change an uncertain request.',
      ),
    );
    chat.changed();
    await original.flushStorage();
    original.dispose();

    failAnswer = false;
    final restored = create();
    await restored.restore();
    expect(restored.storageError, isNull);
    expect(
      sent,
      hasLength(1),
      reason: 'Restoring a recovery record must not send it',
    );
    billingSession = 'c' * 32;
    await ask(restored);
    expect(sent, hasLength(2));
    for (final field in [
      'requestId',
      'billingVersion',
      'billingSession',
      'responseMode',
      'conversationHistory',
      'conversationMemory',
      'previousUserMessages',
      'reportPerson',
    ]) {
      expect(
        sent.last[field],
        sent.first[field],
        reason: '$field must retain the exact saved payload',
      );
    }
    restored.dispose();
  });

  test('Nila Trust sends its own local conversation while retaining the Nila provider voice', () async {
    Map<String, dynamic>? sent;
    final session = ProfileSession(
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('kundli')) {
            return http.Response(
              jsonEncode({
                'sandbox': false,
                'chartTicket': 'test-ticket',
                'profileId': 'test-profile',
                'result': {
                  'data': {
                    'nakshatra_details': {
                      'chandra_rasi': {'name': 'Meena'},
                      'nakshatra': {'name': 'Revati'},
                    },
                  },
                },
              }),
              200,
            );
          }
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"profileId":"test-profile","answer":"A useful answer.","answerMode":"limited_guidance","evidence":[]}',
            200,
          );
        }),
      ),
    );
    await session.calculate(
      dateTime: '2000-01-01T12:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: false,
    );
    session
        .conversation('Nila')
        .messages
        .add(
          const ChatMessage(
            fromUser: true,
            text: 'Legacy family conversation about a sibling.',
          ),
        );
    session.conversation('NilaTrust').messages.addAll(const [
      ChatMessage(
        fromUser: true,
        text: 'Current trust conversation about my partner.',
      ),
      ChatMessage(fromUser: false, text: 'What boundary matters to you?'),
    ]);
    await session.ask(
      category: 'Relationships',
      question: 'How can I express that clearly?',
      responseStyle: 'english',
      guide: 'Nila',
      conversationKey: 'NilaTrust',
      depth: 'standard',
    );
    expect(sent!['guide'], 'Nila');
    expect(sent!['previousUserMessages'], [
      'Current trust conversation about my partner.',
    ]);
    expect(sent!['conversationHistory'], [
      {
        'role': 'user',
        'content': 'Current trust conversation about my partner.',
      },
      {'role': 'assistant', 'content': 'What boundary matters to you?'},
    ]);
    expect(jsonEncode(sent), isNot(contains('Legacy family')));
    session.dispose();
  });

  for (final originalGuide in <String?>['Vetri', null]) {
    test(
      'legacy ${originalGuide ?? 'no-guide'} Detailed recovery preserves receipt and research consent after restart',
      () async {
        String? stored;
        var failAnswer = true;
        final sent = <Map<String, dynamic>>[];
        ProfileSession create() => ProfileSession(
          vault: LocalProfileVault(
            read: () async => stored,
            write: (value) async => stored = value,
          ),
          api: JyotaraApiClient(
            baseUrl: 'https://example.test',
            client: MockClient((request) async {
              if (request.url.path.endsWith('kundli')) {
                return http.Response(
                  jsonEncode({
                    'sandbox': false,
                    'chartTicket': 'test-ticket',
                    'profileId': 'test-profile',
                    'result': {
                      'data': {
                        'nakshatra_details': {
                          'chandra_rasi': {'name': 'Meena'},
                          'nakshatra': {'name': 'Revati'},
                        },
                      },
                    },
                  }),
                  200,
                );
              }
              sent.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (failAnswer) {
                throw http.ClientException('Synthetic uncertain delivery');
              }
              return http.Response(
                '{"profileId":"test-profile","answer":"Recovered answer.","answerMode":"limited_guidance","evidence":[]}',
                200,
              );
            }),
          ),
        );
        const question = 'Should I change my approach?';
        final original = create();
        await original.calculate(
          dateTime: '2000-01-01T12:00:00+05:30',
          latitude: 11,
          longitude: 77,
          exactTime: false,
        );
        await original.flushStorage();
        original.setResearchConsent(true);
        original
            .conversation('Vetri')
            .messages
            .add(
              const ChatMessage(
                fromUser: true,
                text: 'I am preparing for interviews.',
              ),
            );
        await expectLater(
          original.ask(
            category: 'Career',
            question: question,
            responseStyle: 'english',
            guide: originalGuide,
            depth: 'detailed',
          ),
          throwsA(isA<JyotaraApiException>()),
        );
        await original.flushStorage();
        original.dispose();
        // Represent a pre-upgrade receipt: legacy payloads had no response mode or
        // earlier-memory fields. Do not send the synthetic template to a server.
        final legacyRecord = jsonDecode(stored!) as Map<String, dynamic>;
        legacyRecord.remove('conversationModes');
        legacyRecord.remove('conversationMemory');
        stored = jsonEncode(legacyRecord);
        failAnswer = false;
        final restored = create();
        await restored.restore();
        expect(
          restored.researchConsent,
          isFalse,
          reason: 'Opt-in still resets for new questions',
        );
        final recovery = restored.pendingGuidanceRequest(
          category: 'Career',
          question: question,
          responseStyle: 'english',
          guide: 'Vetri',
        );
        expect(recovery, isNotNull);
        expect(recovery!.depth, 'detailed');
        expect(recovery.id, sent.first['requestId']);
        await restored.ask(
          category: 'Career',
          question: question,
          responseStyle: 'english',
          guide: 'Vetri',
          depth: recovery.depth,
          upgradeFrom: recovery.upgrade,
        );
        expect(sent.last['requestId'], sent.first['requestId']);
        expect(sent.last['guide'], sent.first['guide']);
        expect(sent.last['depth'], 'detailed');
        expect(sent.last['researchConsent'], isTrue);
        expect(sent.last.containsKey('responseMode'), isFalse);
        expect(sent.last.containsKey('conversationMemory'), isFalse);
        expect(
          sent.last['conversationHistory'],
          sent.first['conversationHistory'],
        );
        await restored.flushStorage();
        restored.dispose();
      },
    );
  }
}
