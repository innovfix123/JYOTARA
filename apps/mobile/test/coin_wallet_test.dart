import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/guidance_message.dart';
import 'package:jyotara/services/jyotara_api.dart';

class FakeWallet extends AccountService {
  FakeWallet()
    : super(
        token: () => 'test',
        tester: () => 'test',
        account: () => 'account',
      );
  int cost = 30;
  bool enough = true;
  String qrStatus = 'created';
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {
    'mode': walletMode,
    'balance': 200,
    'status': qrStatus,
    'packs': [
      {'id': 'regular', 'coins': 200, 'rupees': 149},
    ],
    'orders': [],
    'activity': [],
    'quote': 'synthetic',
    'category': 'Marriage',
    'depth': 'detailed',
    'cost': cost,
    'canProceed': enough,
    'trial': false,
  };
}

class SwitchingWallet extends FakeWallet {
  final purchases = <Map<String, dynamic>>[];
  final orders = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/create')) {
      purchases.add(Map<String, dynamic>.from(body));
      throw const AccountServiceError('Checkout temporarily unavailable');
    }
    return {
      ...await super.post(path, body),
      'orders': orders,
      'packs': [
        {'id': 'starter', 'coins': 50, 'rupees': 49},
        {'id': 'regular', 'coins': 200, 'rupees': 149},
      ],
    };
  }
}

class NativeWallet extends FakeWallet {
  bool verified = false;
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/create'))
      return {
        'id': 'local-order',
        'orderId': 'order_123',
        'keyId': 'rzp_${walletMode}_example',
        'mode': walletMode,
        'currency': 'INR',
        'amount': 14900,
        'coins': 200,
      };
    if (path.endsWith('/verify')) {
      assert(
        body['id'] == 'local-order' &&
            body['paymentId'] == 'pay_123' &&
            body['signature'] == 'signature',
      );
      verified = true;
      return {'balance': 400};
    }
    final data = await super.post(path, body);
    data['orders'] = verified
        ? [
            {
              'id': 'local-order',
              'status': 'paid',
              'amount': 14900,
              'coins': 200,
            },
          ]
        : [];
    return data;
  }
}

void main() {
  test(
    'verified domain migration allows only the established backend origin',
    () {
      final api = JyotaraApiClient(baseUrl: 'https://api.jyotara.in');
      expect(api.acceptsStorageOrigin('https://168.144.64.47'), true);
      expect(api.acceptsStorageOrigin('https://api.jyotara.in'), true);
      expect(api.acceptsStorageOrigin('https://other.example'), false);
      expect(
        JyotaraApiClient(baseUrl: 'https://other.example')
            .acceptsStorageOrigin('https://168.144.64.47'),
        false,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('razorpay_flutter'),
          (_) async => null,
        );
  });
  testWidgets(
    'native checkout verifies callback before showing credited coins',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final api = NativeWallet();
      bool opened = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('razorpay_flutter'), (
            call,
          ) async {
            if (call.method != 'open') return null;
            opened = true;
            expect(call.arguments['order_id'], 'order_123');
            expect(call.arguments['amount'], 14900);
            expect(api.verified, false);
            return {
              'type': 0,
              'data': {
                'razorpay_order_id': 'order_123',
                'razorpay_payment_id': 'pay_123',
                'razorpay_signature': 'signature',
              },
            };
          });
      await tester.pumpWidget(MaterialApp(home: CoinWalletScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('₹149'));
      await tester.pumpAndSettle();
      expect(opened, true);
      expect(api.verified, true);
      expect(find.text('Payment verified. Coins added.'), findsOneWidget);
    },
  );
  testWidgets(
    'switching packs preserves old retry and clears completed purchases',
    (tester) async {
      final base = 'jyotara.coin-purchase.$walletMode.account';
      FlutterSecureStorage.setMockInitialValues({
        base: jsonEncode({
          'requestId': 'legacy-starter-request',
          'packId': 'starter',
          'paymentMethod': 'checkout',
          'id': 'old-order',
        }),
      });
      final api = SwitchingWallet();
      await tester.pumpWidget(MaterialApp(home: CoinWalletScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('₹149'));
      await tester.pumpAndSettle();
      expect(api.purchases.single['packId'], 'regular');
      final regularId = api.purchases.single['requestId'];
      expect(regularId, isNot('legacy-starter-request'));
      await tester.tap(find.text('₹49'));
      await tester.pumpAndSettle();
      expect(api.purchases.last['requestId'], 'legacy-starter-request');
      await tester.tap(find.text('₹149'));
      await tester.pumpAndSettle();
      expect(api.purchases.last['requestId'], regularId);
      expect(find.textContaining('different pack is awaiting'), findsNothing);
      api.orders.add({
        'id': 'old-order',
        'status': 'paid',
        'amount': 4900,
        'coins': 50,
        'pack_id': 'starter',
      });
      await tester.tap(find.text('₹49'));
      await tester.pumpAndSettle();
      expect(api.purchases.last['requestId'], isNot('legacy-starter-request'));
    },
  );

  testWidgets(
    'wallet shows category prices and does not promise relationship answer equivalence',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: CoinWalletScreen(api: FakeWallet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('200 coins'), findsWidgets);
      await tester.scrollUntilVisible(find.text('₹149'), 100);
      expect(find.text('₹149'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(
          walletMode == 'test'
              ? 'TEST MODE · No real money'
              : 'Secure payment via Razorpay · Prices in INR',
        ),
        100,
      );
      expect(
        find.text('TEST MODE · No real money'),
        walletMode == 'test' ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('general Standard answers'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Chat: 10 coins'),
        200,
      );
      expect(find.textContaining('Relationships: 15 coins'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('confirmation cancels without sending a paid request', (
    tester,
  ) async {
    coinAccount = FakeWallet();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: coinNavigator, home: const Scaffold()),
    );
    Object? failure;
    final pending = confirmCoins('guidance', {'question': 'Marriage?'})
        .catchError((Object e) {
          failure = e;
          return <String, dynamic>{};
        });
    await tester.pumpAndSettle();
    expect(find.text('Use 30 coins'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await pending;
    expect(failure.toString(), contains('No coins used'));
  });
  testWidgets(
    'selected chat rate skips repeat dialogs but higher prices need confirmation',
    (tester) async {
      final api = FakeWallet();
      coinAccount = api;
      await tester.pumpWidget(
        MaterialApp(navigatorKey: coinNavigator, home: const Scaffold()),
      );
      const consent = CoinChatConsent('account', 'detailed', 30);
      for (var i = 0; i < 2; i++) {
        final result = await withCoinChatConsent(
          consent,
          () => confirmCoins('guidance', {'depth': 'detailed'}),
        );
        expect(result['coinQuote'], 'synthetic');
        expect(find.byType(AlertDialog), findsNothing);
      }
      api.cost = 40;
      Object? failure;
      final pending =
          withCoinChatConsent(
            consent,
            () => confirmCoins('guidance', {'depth': 'detailed'}),
          ).catchError((Object e) {
            failure = e;
            return <String, dynamic>{};
          });
      await tester.pumpAndSettle();
      expect(find.text('Use 40 coins'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pending;
      expect(failure, isNotNull);
      api.cost = 30;
      api.enough = false;
      await expectLater(
        withCoinChatConsent(
          consent,
          () => confirmCoins('guidance', {'depth': 'detailed'}),
        ),
        throwsA(isA<AccountServiceError>()),
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  test(
    'minute consent permits only the disclosed 40-coin rate for its owner',
    () {
      const consent = CoinChatConsent('owner', 'standard', 15);
      const payload = {'billingVersion': 2, 'depth': 'standard'};
      final quote = {
        'billingVersion': 2,
        'coinsPerMinute': 40,
        'cost': 40,
        'canProceed': true,
      };
      expect(consent.accepts('owner', payload, quote), isTrue);
      expect(consent.accepts('owner', payload, {...quote, 'cost': 0}), isTrue);
      for (final invalid in [
        {...quote, 'cost': 41},
        {...quote, 'cost': -1},
        {...quote, 'coinsPerMinute': 80},
        {...quote, 'billingVersion': 3},
        {...quote, 'canProceed': false},
      ]) {
        expect(consent.accepts('owner', payload, invalid), isFalse);
      }
      expect(consent.accepts('another-owner', payload, quote), isFalse);
      expect(consent.accepts(null, payload, quote), isFalse);
      expect(
        coinReceiptLabel({'billingVersion': 2, 'status': 'failed', 'coins': 0}),
        'Not charged',
      );
      expect(
        coinReceiptLabel({
          'billingVersion': 2,
          'status': 'complete',
          'coins': 0,
        }),
        'Included in chat',
      );
    },
  );
  test('chat consent is account, depth and upgrade bound', () {
    const c = CoinChatConsent('a', 'standard', 15);
    final q = {
      'category': 'Love',
      'depth': 'standard',
      'cost': 15,
      'canProceed': true,
    };
    expect(c.accepts('a', {'depth': 'standard'}, q), true);
    expect(c.accepts('b', {'depth': 'standard'}, q), false);
    expect(c.accepts('a', {'depth': 'detailed'}, q), false);
    expect(
      c.accepts('a', {'depth': 'standard', 'upgradeFrom': 'other'}, q),
      false,
    );
    expect(c.accepts(null, {'depth': 'standard'}, q), false);
    expect(
      c.accepts('a', {'depth': 'standard'}, {...q, 'category': 'Career'}),
      false,
    );
  });
  testWidgets('Home shows only a tappable balance with enlarged text', (
    tester,
  ) async {
    coinAccount = FakeWallet();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: const HomeCoinCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('200 coins'), findsOneWidget);
    expect(find.textContaining('₹149'), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'wallet receipt survives answer formatting for later same-answer upgrade',
    () {
      final result = GuidanceResponse.fromJson({
        'answer': 'A completed reading.',
        'evidence': [],
        'answerMode': 'provider_reading',
        'wallet': {
          'id': 'receipt',
          'canUpgrade': true,
          'upgradeCost': 15,
          'question': 'Marriage?',
          'style': 'english',
        },
      });
      final ChatMessage message = guidanceMessage(result, 'english');
      expect(message.wallet?['id'], 'receipt');
      expect(message.wallet?['upgradeCost'], 15);
    },
  );
  testWidgets('QR never claims payment success before server confirmation', (
    tester,
  ) async {
    final api = FakeWallet();
    final order = {
      'id': 'purchase',
      'coins': 50,
      'amount': 4900,
      'imageUrl': 'https://rzp.io/i/synthetic',
      'expiresAt': 0,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: CoinQrScreen(api: api, order: order),
      ),
    );
    await tester.pump();
    expect(find.text('Payment verified. Coins added.'), findsNothing);
    expect(find.textContaining('This QR has expired'), findsOneWidget);
    api.qrStatus = 'paid';
    await tester.tap(find.text('Check payment'));
    await tester.pumpAndSettle();
    expect(find.text('Payment verified. Coins added.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
