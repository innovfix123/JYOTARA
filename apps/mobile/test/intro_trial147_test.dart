import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';

import 'profile_replacement_test.dart' show chartReply;

const trialId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, dynamic> trialState({
  String state = 'active',
  bool started = false,
}) => {
  'state': state,
  'durationMs': 60000,
  'remainingMs': state == 'ended' ? 0 : 60000,
  'started': started,
  'pending': false,
  'billingSession': trialId,
  'guide': 'Meera',
};

class TrialWallet extends AccountService {
  TrialWallet()
    : super(
        token: () => 'fixture',
        tester: () => null,
        account: () => 'trial-owner',
      );
  final operations = <String>[];
  var state = 'available';
  var quotes = 0;
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/intro-trial')) {
      operations.add(body['operation']);
      if (body['operation'] == 'offer') state = 'offered';
      if (body['operation'] == 'start') state = 'active';
      if (body['operation'] == 'finish') state = 'ended';
      if (body['operation'] == 'skip') state = 'skipped';
      return trialState(state: state);
    }
    if (path.endsWith('/quote')) {
      quotes++;
      return {
        'quote': 'fixture-free-trial',
        'category': 'Love',
        'depth': 'standard',
        'cost': 0,
        'trial': true,
        'canProceed': true,
        'billingVersion': 2,
        'coinsPerMinute': 40,
        'introTrial': trialState(),
      };
    }
    return {
      'mode': walletMode,
      'balance': 0,
      'packs': [
        {'id': 'minuteentry', 'coins': 40, 'rupees': 25},
      ],
      'orders': [],
      'activity': [],
    };
  }
}

Future<ProfileSession> profile() async {
  final api = JyotaraApiClient(
    baseUrl: 'https://example.test',
    client: MockClient((r) async {
      if (r.url.path.endsWith('/kundli')) return chartReply('trial-profile');
      final body = jsonDecode(r.body);
      if (r.url.path.endsWith('/status')) {
        return http.Response(
          jsonEncode({
            'requestId': body['requestId'],
            'profileId': body['profileId'],
            'state': 'absent',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'profileId': 'trial-profile',
          'answer': 'Your chart suggests a patient approach to love.',
          'answerMode': 'provider_reading',
          'evidence': [],
          'wallet': {
            'id': 'trial-answer',
            'status': 'complete',
            'coins': 0,
            'trial': true,
            'introTrial': trialState(started: true),
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
  addTearDown(api.close);
  await session.calculate(
    dateTime: '2000-01-01T05:00:00+05:30',
    latitude: 11,
    longitude: 77,
    exactTime: true,
  );
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('razorpay_flutter'),
          (_) async => null,
        );
  });
  tearDown(() => coinAccount = null);

  test('trial consent never accepts paid or foreign-session quotes', () {
    const consent = CoinChatConsent(
      'owner',
      'standard',
      40,
      introSession: trialId,
    );
    const payload = {'billingVersion': 2};
    final quote = {
      'billingVersion': 2,
      'coinsPerMinute': 40,
      'cost': 0,
      'trial': true,
      'canProceed': true,
      'introTrial': trialState(),
    };
    expect(consent.accepts('owner', payload, quote), true);
    expect(consent.accepts('owner', payload, {...quote, 'cost': 40}), false);
    expect(consent.accepts('other', payload, quote), false);
    expect(
      consent.accepts('owner', payload, {
        ...quote,
        'introTrial': {'billingSession': 'b' * 32},
      }),
      false,
    );
    expect(
      coinReceiptLabel({
        'coins': 0,
        'introTrial': trialState(),
        'status': 'complete',
      }),
      'Free trial',
    );
  });

  testWidgets(
    'trial uses free answers, finishes into packages, and can return to free Home',
    (t) async {
      final session = await profile();
      final wallet = TrialWallet()..state = 'active';
      coinAccount = wallet;
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: coinNavigator,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Free home'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      guide: guides.first,
                      session: session,
                      introTrial: trialState(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Free home'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('chatInput')),
        'What does my chart suggest about love?',
      );
      await t.tap(find.byKey(const Key('sendMessage')));
      await t.pump();
      await t.pump(const Duration(seconds: 6));
      await t.pump();
      await t.pump(const Duration(seconds: 15));
      await t.pump();
      expect(wallet.quotes, 1);
      expect(
        session
            .conversation(guides.first.conversationKey)
            .messages
            .where((m) => m.wallet != null)
            .single
            .wallet?['coins'],
        0,
      );
      expect(find.text('Use 40 coins'), findsNothing);
      await t.tap(find.byKey(const Key('end-chat')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.byType(CoinWalletScreen), findsOneWidget);
      expect(wallet.operations, contains('finish'));
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.text('Free home'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
