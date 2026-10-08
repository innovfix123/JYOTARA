import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  testWidgets('resumed deletion returns to empty interactive mobile login', (
    tester,
  ) async {
    var saved = jsonEncode({
      'accountId': 'b' * 32,
      'mobile': '9000000000',
      'token': 'a' * 64,
      'serverDeleted': true,
      'deletionPending': true,
      'expiresAt': 1,
    });
    var erased = false;
    final access = PhoneAccess(
      testerCode: () => null,
      read: () async => saved,
      write: (v) async {
        saved = v;
      },
      eraseLocalAccount: (id) async {
        expect(id, 'b' * 32);
        erased = true;
      },
    );
    await access.restore();
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneAccessScreen(
          access: access,
          child: const Text('Private app'),
        ),
      ),
    );
    expect(find.text('Finish account deletion'), findsOneWidget);
    expect(await access.deleteAccount(), isTrue);
    await tester.pump();
    expect(erased, isTrue);
    expect(find.text('Finish account deletion'), findsNothing);
    final phone = tester.widget<TextField>(find.byType(TextField).first);
    expect(phone.controller!.text, isEmpty);
    expect(access.mobile, isNull);
    expect(access.codeSent, isFalse);
    expect(jsonDecode(saved), isEmpty);
    await tester.showKeyboard(find.byType(TextField).first);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField).first, '9111111111');
    expect(phone.controller!.text, '9111111111');
    await tester.pumpWidget(const SizedBox.shrink());
    access.dispose();
  });
}
