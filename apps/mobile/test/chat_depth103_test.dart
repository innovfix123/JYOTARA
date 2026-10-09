import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/chat_availability.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/remote_config.dart';

import 'profile_replacement_test.dart' show chartReply;

class _ChatWallet extends AccountService {
  _ChatWallet(this.enough)
    : super(
        token: () => 'fixture',
        tester: () => null,
        account: () => 'fixture-account',
      );
  final bool enough;
  int cost = 10;
  int quotes = 0;
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    quotes++;
    return {
      'quote': 'fixture',
      'category': 'Education',
      'depth': 'standard',
      'cost': cost,
      'balance': enough ? 100 : 0,
      'canProceed': enough,
    };
  }
}

void main() {
  testWidgets('guide chooser displays AI identity and prices without a popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GuidesScreen(onOpenChat: (_) {})),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI guides'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('chatPriceNotice'))).data,
      'General questions: 10 coins per answer. '
      'Relationship questions: 15 coins per answer. '
      'Only completed answers are charged.',
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, skip: !coinWalletEnabled);

  for (final enough in [true, false]) {
    testWidgets(
      enough
          ? 'ordinary send uses standard quote with no Start chat popup and a short subject header'
          : 'no Start chat popup still rejects an insufficient server quote',
      (tester) async {
        final wallet = _ChatWallet(enough);
        coinAccount = wallet;
        addTearDown(() => coinAccount = null);
        final calls = <Map<String, dynamic>>[];
        final api = JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/kundli')) {
              return chartReply('fixture-profile');
            }
            final body = Map<String, dynamic>.from(jsonDecode(request.body));
            if (request.url.path.endsWith('/status')) {
              return http.Response(
                jsonEncode({
                  'requestId': body['requestId'],
                  'profileId': body['profileId'],
                  'state': 'absent',
                }),
                200,
              );
            }
            calls.add(body);
            return http.Response(
              jsonEncode({
                'profileId': 'fixture-profile',
                'answer': 'A complete fixture answer.',
                'answerMode': 'provider_reading',
                'evidence': [],
                'wallet': {
                  'id': 'fixture-receipt',
                  'status': 'complete',
                  'coins': 10,
                },
              }),
              200,
            );
          }),
        );
        final session = ProfileSession(
          api: api,
          vault: LocalProfileVault(read: () async => null, write: (_) async {}),
        );
        await session.calculate(
          dateTime: '2000-01-01T05:00:00+05:30',
          latitude: 11,
          longitude: 77,
          exactTime: true,
        );
        final guide = guides.firstWhere(
          (guide) => guide.category == 'Education',
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: coinNavigator,
            home: ChatScreen(guide: guide, session: session),
          ),
        );
        await tester.pump();
        final header = find.byKey(const Key('softBronzeChatHeader'));
        expect(
          find.descendant(of: header, matching: find.text('Education')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('AI guide')),
          findsNothing,
        );
        await tester.enterText(
          find.byKey(const Key('chatInput')),
          'Which studies suit me?',
        );
        await tester.tap(find.byKey(const Key('sendMessage')));
        await tester.pump();
        expect(find.text('Which studies suit me?'), findsOneWidget);
        expect(find.text('Start chat'), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
        await tester.pump();
        expect(wallet.quotes, 1);
        expect(find.byType(AlertDialog), findsNothing);
        if (enough) {
          expect(calls, hasLength(1));
          expect(calls.single['depth'], 'standard');
          expect(calls.single['coinQuote'], 'fixture');
          expect(calls.single['userMessageBatch'], ['Which studies suit me?']);
        } else {
          expect(
            calls,
            isEmpty,
            reason: 'An insufficient quote must prevent guidance dispatch',
          );
          expect(
            session.conversation(guide.conversationKey).turns.single.state,
            'failed',
          );
        }
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        api.close();
      },
      skip: !coinWalletEnabled || !publicChatEnabled,
    );
  }

  testWidgets(
    'remote price increase after entry cannot silently authorize the first send',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final wallet = _ChatWallet(true)..cost = 15;
      coinAccount = wallet;
      addTearDown(() => coinAccount = null);
      var guidancePosts = 0;
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/kundli')) {
            return chartReply('fixture-profile');
          }
          if (request.url.path.endsWith('/status')) {
            final body = jsonDecode(request.body);
            return http.Response(
              jsonEncode({
                'requestId': body['requestId'],
                'profileId': body['profileId'],
                'state': 'absent',
              }),
              200,
            );
          }
          guidancePosts++;
          return http.Response('{}', 200);
        }),
      );
      final session = ProfileSession(
        api: api,
        vault: LocalProfileVault(read: () async => null, write: (_) async {}),
      );
      await session.calculate(
        dateTime: '2000-01-01T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      final guide = guides.firstWhere((guide) => guide.category == 'Education');
      expect(remoteConfig.cost('generalStandard', 10), 10);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: coinNavigator,
          home: ChatScreen(guide: guide, session: session),
        ),
      );
      await tester.pump();
      final updatedConfig = {
        'schema': 1,
        'revision': 2,
        'features': <String, bool>{},
        'maintenance': false,
        'message': '',
        'announcement': '',
        'supportEmail': '',
        'languages': ['english', 'tamil', 'tanglish'],
        'disabledGuides': <String>[],
        'disabledPacks': <String>[],
        'guideDescriptions': <String, String>{},
        'exploreCards': <Map<String, String>>[],
        'costs': {'generalStandard': 15, 'relationshipStandard': 20},
      };
      await http.runWithClient(
        () => remoteConfig.refresh(),
        () => MockClient(
          (_) async => http.Response(jsonEncode(updatedConfig), 200),
        ),
      );
      expect(remoteConfig.cost('generalStandard', 10), 15);
      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'Which studies suit me?',
      );
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pump();
      final chat = session.conversation(guide.conversationKey);
      expect(chat.acceptedGeneralCoins, 10);
      expect(chat.acceptedRelationshipCoins, 15);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(wallet.quotes, 1);
      expect(guidancePosts, 0);
      expect(find.widgetWithText(FilledButton, 'Use 15 coins'), findsOneWidget);
      expect(chat.turns.single.ack, 'queued');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(guidancePosts, 0);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    },
    skip: !coinWalletEnabled || !publicChatEnabled,
  );
}
