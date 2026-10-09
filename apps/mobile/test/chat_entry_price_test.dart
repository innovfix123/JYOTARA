import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/chat_availability.dart';
import 'package:jyotara/chat_profile_picker.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/remote_config.dart';

import 'profile_replacement_test.dart' show chartReply;

class _RaisedPriceWallet extends AccountService {
  _RaisedPriceWallet()
    : super(
        token: () => 'fixture',
        tester: () => null,
        account: () => 'fixture-account',
      );
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
      'cost': 15,
      'balance': 100,
      'canProceed': true,
    };
  }
}

void main() {
  testWidgets(
    'chooser prices survive a remote price rise while profile selection stays open',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final wallet = _RaisedPriceWallet();
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
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: coinNavigator,
          home: ChatProfilePicker(
            guide: guide,
            generalCoins: 10,
            relationshipCoins: 15,
            loadProfiles: () async => [SavedKundli('fixture', session)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsNothing);
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
      expect(find.byType(ChatProfilePicker), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-profile-fixture')));
      await tester.pumpAndSettle();
      final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chatScreen.generalCoins, 10);
      expect(chatScreen.relationshipCoins, 15);
      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'Which studies suit me?',
      );
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pump();
      final chat = session.conversation(guide.conversationKey);
      expect(chat.acceptedGeneralCoins, 10);
      expect(chat.acceptedRelationshipCoins, 15);
      expect(find.text('Start chat'), findsNothing);
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
