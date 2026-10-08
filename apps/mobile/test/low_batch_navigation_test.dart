import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/firebase_preferences.dart';
import 'package:jyotara/notification_center.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/ui_language.dart';

import 'coin_wallet_test.dart' show FakeWallet;

void main() {
  testWidgets('phone login excludes reviewer access without making requests', (
    tester,
  ) async {
    var calls = 0;
    final access = PhoneAccess(
      testerCode: () => null,
      read: () async => null,
      write: (_) async {},
      client: MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode({'error': 'Invalid review credentials.'}),
          401,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneAccessScreen(access: access, child: const Text('Signed in')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App reviewer access'), findsNothing);
    expect(find.widgetWithText(TextField, 'Review username'), findsNothing);
    expect(find.text('Enter your mobile number to begin.'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });
  testWidgets('Explore keeps its header above scrolling cards', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ExploreScreen())),
    );
    await tester.pumpAndSettle();
    final y = tester.getTopLeft(find.text('Explore astrology')).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Explore astrology')).dy, y);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'chat retains composer focus and shows latest greeting after keyboard resize',
    (tester) async {
      final session = ProfileSession();
      session
          .conversation(guides.first.conversationKey)
          .messages
          .addAll(
            List.generate(
              20,
              (i) => ChatMessage(
                fromUser: false,
                text:
                    'Previous guidance $i. Take your time and talk openly about what is on your mind.',
              ),
            ),
          );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chatInput')), 'hi');
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('chatInput')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.controller!.text, isEmpty);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(
        find.byKey(const Key('chatHistoryList')),
      );
      expect(list.controller!.position.maxScrollExtent, greaterThan(0));
      expect(
        list.controller!.offset,
        closeTo(list.controller!.position.maxScrollExtent, 1),
      );
      expect(find.text(guides.first.speciality), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'notification settings opens separately and app language has one settings entry',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AccountSettingsScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FirebasePreferences), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Notification settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Notification settings'));
      await tester.tap(find.text('Notification settings'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
      expect(find.byType(FirebasePreferences), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(FirebasePreferences), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AccountScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('App Language'), findsNothing);
    },
  );
  testWidgets('wallet opened from Home preserves Home highlight', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('razorpay_flutter'),
          (_) async => null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('razorpay_flutter'),
            null,
          ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CoinWalletScreen(api: FakeWallet(), originTab: 0)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });
  test('Tamil handles provider star spelling aliases without changing English text', () {
    expect(tamilBirthStar('Aswini'), 'அஸ்வினி');
    expect(tamilBirthStar('ASHWINI'), 'அஸ்வினி');
    expect(tamilBirthStar('Purva Ashadha'), 'பூராடம்');
    expect(tamilBirthStar('Unknown star'), isNull);
  });
}
