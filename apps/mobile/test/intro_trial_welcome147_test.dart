import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/main.dart';

import 'intro_trial147_test.dart' show profile, TrialWallet;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => coinAccount = null);
  testWidgets(
    'first-visit offer starts the existing Ask chat without a payment prompt',
    (t) async {
      expect(
        introTrialEnabled && minuteBillingEnabled && coinWalletEnabled,
        true,
      );
      final original = profileSession;
      final session = await profile();
      final wallet = TrialWallet();
      profileSession = session;
      addTearDown(() => profileSession = original);
      coinAccount = wallet;
      await t.pumpWidget(
        MaterialApp(navigatorKey: coinNavigator, home: const MainShell()),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('introTrialOffer')), findsOneWidget);
      await t.tap(find.byKey(const Key('startIntroTrial')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byKey(const Key('introTrialTimer')), findsOneWidget);
      expect(find.byType(CoinWalletScreen), findsNothing);
      expect(
        wallet.operations,
        containsAllInOrder(['status', 'offer', 'start']),
      );
      await t.pumpWidget(const SizedBox());
      profileSession = original;
      session.dispose();
    },
  );
}
