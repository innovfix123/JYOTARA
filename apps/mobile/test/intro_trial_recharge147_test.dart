import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:flutter/services.dart';

import 'coin_wallet_test.dart' show NativeWallet;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => coinAccount = null);
  testWidgets(
    'only a verified recharge returns from packages to the same chat route',
    (t) async {
      final wallet = NativeWallet();
      bool? paid;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('razorpay_flutter'), (
            call,
          ) async {
            if (call.method != 'open') return null;
            expect(wallet.verified, false);
            return {
              'type': 0,
              'data': {
                'razorpay_order_id': 'order_123',
                'razorpay_payment_id': 'pay_123',
                'razorpay_signature': 'signature',
              },
            };
          });
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Same chat'),
                onPressed: () async {
                  paid = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) =>
                          CoinWalletScreen(api: wallet, returnToChat: true),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Same chat'));
      await t.pumpAndSettle();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();
      expect(paid, null);
      expect(find.byType(CoinWalletScreen), findsOneWidget);
      await t.tap(find.text('₹149'));
      await t.pumpAndSettle();
      expect(wallet.verified, true);
      expect(paid, true);
      expect(find.byType(CoinWalletScreen), findsNothing);
      expect(find.text('Same chat'), findsOneWidget);
    },
  );
}
