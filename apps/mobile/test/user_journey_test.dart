import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/user_journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var account = 'owner-a';
  String? token = 'a' * 64;
  late List<Map<String, dynamic>> sent;
  var sequence = 0;
  String identifier() => (++sequence).toRadixString(16).padLeft(32, '0');
  setUp(() {
    account = 'owner-a';
    token = 'a' * 64;
    sent = [];
    sequence = 0;
  });
  Future<UserJourney> service({bool fail = false, String? initial}) async {
    final journey = UserJourney(
      automaticFlush: false,
      identifier: identifier,
      readQueue: () async => initial,
      writeQueue: (_) async {},
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/api/user-journey');
        expect(body.containsKey('accountId'), false);
        sent.add({'authorization': request.headers['authorization'], ...body});
        return http.Response(
          fail
              ? '{}'
              : jsonEncode({
                  'accepted': (body['events'] as List)
                      .map((e) => e['id'])
                      .toList(),
                }),
          fail ? 503 : 200,
        );
      }),
    );
    await journey.initialize(
      baseUrl: 'https://example.test',
      account: () => account,
      token: () => token,
    );
    return journey;
  }

  test(
    'records metadata only, preserves exact IDs after network failure',
    () async {
      final journey = await service(fail: true);
      journey.screen('chat');
      journey.event(
        'chat.send',
        metadata: {
          'question': 'secret question',
          'phone': '9000000000',
          'outcome': 'started',
          'feature': 'chat',
          'control': 'send',
        },
      );
      await journey.flush();
      await journey.flush();
      expect(sent.length, 2);
      expect(sent[0], sent[1]);
      expect(journey.pendingCount, greaterThan(0));
      final body = jsonEncode(sent);
      expect(body.contains('secret question'), false);
      expect(body.contains('9000000000'), false);
      expect(body.contains('owner-a'), false);
      expect((sent.first['events'] as List).last['metadata'], {
        'outcome': 'started',
        'feature': 'chat',
        'control': 'send',
      });
      journey.dispose();
    },
  );

  test(
    'anonymous onboarding joins verified account and logout separates history',
    () async {
      token = null;
      final journey = await service();
      journey.screen('login');
      journey.event('auth.send', metadata: {'outcome': 'started'});
      await journey.flush();
      expect(sent, isEmpty);
      token = 'a' * 64;
      journey.event('auth.verify', metadata: {'outcome': 'success'});
      await journey.flush();
      expect(journey.pendingCount, 0);
      expect(
        (sent.single['events'] as List).any((e) => e['name'] == 'auth.send'),
        true,
      );
      token = null;
      await journey.discardAccount();
      journey.screen('login');
      journey.event('auth.send', metadata: {'outcome': 'started'});
      account = 'owner-b';
      token = 'b' * 64;
      journey.event('auth.verify', metadata: {'outcome': 'success'});
      await journey.flush();
      expect(sent.last['authorization'], 'Bearer ${'b' * 64}');
      expect(
        (sent.last['events'] as List).any((e) => e['name'] == 'auth.verify'),
        true,
      );
      expect(
        (sent.last['events'] as List)
            .map((e) => e['id'])
            .toSet()
            .intersection(
              (sent.first['events'] as List).map((e) => e['id']).toSet(),
            ),
        isEmpty,
      );
      journey.dispose();
    },
  );

  test(
    'account switch cannot relabel queued events from previous account',
    () async {
      final journey = await service(fail: true);
      journey.event('chat.send');
      await journey.flush();
      final old = (sent.first['events'] as List).map((e) => e['id']).toSet();
      account = 'owner-b';
      token = 'b' * 64;
      journey.event('app.foreground');
      await journey.flush();
      expect(
        (sent.last['events'] as List)
            .map((e) => e['id'])
            .toSet()
            .intersection(old),
        isEmpty,
      );
      journey.dispose();
    },
  );

  test(
    'expired login retains own queue until same account verifies again',
    () async {
      final journey = await service(fail: true);
      journey.event('chat.answer');
      await journey.flush();
      final old = (sent.first['events'] as List).map((e) => e['id']).toSet();
      token = null;
      journey.event('auth.send');
      await journey.flush();
      token = 'a' * 64;
      journey.event('auth.verify');
      await journey.flush();
      expect(
        (sent.last['events'] as List)
            .map((e) => e['id'])
            .toSet()
            .containsAll(old),
        true,
      );
      journey.dispose();
    },
  );

  test(
    'persisted foreign queue and unexpected metadata are never uploaded',
    () async {
      final initial = jsonEncode([
        {
          'id': 'c' * 32,
          'sessionId': 'd' * 32,
          'sequence': 1,
          'name': 'chat.send',
          'screen': 'chat',
          'at': 1,
          'owner': 'different',
          'metadata': {},
        },
        {
          'id': 'e' * 32,
          'sessionId': 'f' * 32,
          'sequence': 1,
          'name': 'chat.send',
          'screen': 'chat',
          'at': 1,
          'owner': null,
          'metadata': {'question': 'private'},
        },
      ]);
      final journey = await service(initial: initial);
      await journey.flush();
      expect((sent.single['events'] as List).length, 1);
      expect((sent.single['events'] as List).single['name'], 'app.open');
      journey.dispose();
    },
  );

  testWidgets('global tap boundary records only screen, no field contents', (
    tester,
  ) async {
    final journey = await service();
    journey.screen('birth_details');
    await tester.pumpWidget(
      MaterialApp(
        home: UserJourneyBoundary(
          journey: journey,
          child: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Text('Private name'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Private name'));
    await journey.flush();
    expect((sent.single['events'] as List).last['name'], 'interaction.tap');
    expect(jsonEncode(sent).contains('Private name'), false);
    journey.dispose();
  });
}
