import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';
import 'package:jyotara/coin_wallet.dart';

void main() {
  testWidgets(
    'logout clears mounted fields and new SMS autofill remains enabled',
    (tester) async {
      String? saved;
      var send = 0;
      final access = PhoneAccess(
        testerCode: () => 'qa',
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/send')
                  ? {'challengeId': (++send == 1 ? 'b' : 'c') * 48}
                  : r.url.path.endsWith('/logout')
                  ? {}
                  : {
                      'token': 'a' * 64,
                      'accountId': 'qa-account',
                      'expiresAt': DateTime.now()
                          .add(const Duration(days: 1))
                          .millisecondsSinceEpoch,
                    },
            ),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneAccessScreen(
            access: access,
            child: const Scaffold(body: Text('Signed in')),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '9000000000');
      await access.send('9000000000');
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '123456');
      await access.verify('123456');
      await tester.pump();
      expect(find.text('Signed in'), findsOneWidget);
      await access.signOut();
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(access.mobile, isNull);
      expect(access.codeSent, isFalse);
      expect(access.resendAt, isNull);
      expect(jsonDecode(saved!), {'accountId': 'qa-account'});
      final reopened = PhoneAccess(
        testerCode: () => 'qa',
        read: () async => saved,
      );
      await reopened.restore();
      expect(reopened.mobile, isNull);
      expect(reopened.codeSent, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneAccessScreen(
            access: reopened,
            child: const Scaffold(body: Text('Signed in')),
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextField).first);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneAccessScreen(
            access: access,
            child: const Scaffold(body: Text('Signed in')),
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextField).first);
      expect(tester.testTextInput.isVisible, isTrue);
      await access.send('9111111111');
      await tester.pump();
      final otp = tester.widget<TextField>(find.byType(TextField).last);
      expect(otp.controller!.text, isEmpty);
      expect(otp.autofillHints, contains(AutofillHints.oneTimeCode));
      await tester.showKeyboard(find.byType(TextField).last);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byType(TextField).last, '65432');
      await tester.enterText(find.byType(TextField).first, '9222222222');
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
      reopened.dispose();
    },
  );
  test('receipt distinguishes free allowance, paid answers and failures', () {
    expect(
      coinReceiptLabel({
        'depth': 'standard',
        'status': 'complete',
        'trial': true,
        'coins': 0,
      }),
      contains('Introductory answer · Free'),
    );
    expect(
      coinReceiptLabel({
        'depth': 'standard',
        'status': 'complete',
        'trial': false,
        'coins': 15,
      }),
      'standard · 15 coins',
    );
    expect(
      coinReceiptLabel({
        'depth': 'detailed',
        'status': 'failed',
        'coins': 0,
        'freeReason': 'general_guidance',
      }),
      'detailed · General guidance · Free',
    );
    expect(
      coinReceiptLabel({
        'depth': 'standard',
        'status': 'failed',
        'trial': true,
        'coins': 0,
      }),
      'standard · Not charged',
    );
  });
}
