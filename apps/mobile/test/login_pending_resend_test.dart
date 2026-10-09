import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';

class _Login {
  DateTime now = DateTime(2026, 10, 9, 12);
  String? saved;
  int sends = 0;
  int autofillStarts = 0;
  final sentNumbers = <String>[];
  Completer<int>? autofillPending;
  Completer<http.Response>? sendPending;

  PhoneAccess createAccess() => PhoneAccess(
    testerCode: () => null,
    requireRealSms: true,
    now: () => now,
    read: () async => saved,
    write: (value) async => saved = value,
    client: MockClient((request) async {
      expect(request.url.path.endsWith('/send'), isTrue);
      sends++;
      sentNumbers.add((jsonDecode(request.body) as Map)['mobile'] as String);
      return sendPending?.future ?? Future.value(challenge());
    }),
  );

  http.Response challenge() =>
      http.Response(jsonEncode({'challengeId': 'b' * 48}), 200);

  void mockAutofill() {
    const channel = MethodChannel('jyotara/otp-autofill');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'start') return null;
      autofillStarts++;
      return autofillPending?.future ?? Future.value(autofillStarts);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
}

Future<void> _open(WidgetTester tester, PhoneAccess access) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PhoneAccessScreen(access: access, child: const Text('Signed in')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _acceptConsent(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

Future<PhoneAccess> _restoreExpiredChallenge(
  WidgetTester tester,
  _Login login,
) async {
  final original = login.createAccess();
  await _open(tester, original);
  await tester.enterText(find.byType(TextField).first, '9000000000');
  await _acceptConsent(tester);
  expect(login.sends, 1);
  expect(original.codeSent, isTrue);
  await tester.enterText(find.byType(TextField).last, '12345');
  await tester.pumpWidget(const SizedBox());
  original.dispose();
  login.now = login.now.add(const Duration(minutes: 5));
  final restored = login.createAccess();
  await restored.restore();
  expect(restored.codeSent, isTrue);
  expect(restored.codeExpired, isTrue);
  await _open(tester, restored);
  expect(login.sends, 1, reason: 'Reopening never sends automatically');
  expect(
    tester.widget<TextField>(find.byType(TextField).last).controller!.text,
    isEmpty,
  );
  return restored;
}

Future<void> _close(WidgetTester tester, PhoneAccess access) async {
  await tester.pumpWidget(const SizedBox());
  access.dispose();
}

void main() {
  testWidgets('restored same-number expired OTP resends explicitly once', (
    tester,
  ) async {
    final login = _Login()..mockAutofill();
    final access = await _restoreExpiredChallenge(tester, login);
    expect(find.byType(Checkbox), findsNothing);
    final resend = find.widgetWithText(TextButton, 'Resend OTP');
    await tester.ensureVisible(resend);
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    await tester.tap(resend);
    await tester.pumpAndSettle();
    expect(login.sends, 2);
    expect(login.sentNumbers, ['9000000000', '9000000000']);
    expect(access.codeExpired, isFalse);
    expect(find.text('Code expires in 5:00'), findsOneWidget);
    expect(find.text('Resend OTP'), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester, access);
  });

  testWidgets('fresh full phone number never sends before explicit consent', (
    tester,
  ) async {
    final login = _Login()..mockAutofill();
    final access = login.createAccess();
    await _open(tester, access);
    await tester.enterText(find.byType(TextField).first, '9000000000');
    await tester.pump(const Duration(seconds: 2));
    expect(login.sends, 0);
    expect(login.autofillStarts, 0);
    expect(access.codeSent, isFalse);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await _acceptConsent(tester);
    expect(login.sends, 1);
    await _close(tester, access);
  });

  testWidgets('changing a restored number cannot reuse challenge consent', (
    tester,
  ) async {
    final login = _Login()..mockAutofill();
    final access = await _restoreExpiredChallenge(tester, login);
    await tester.enterText(find.byType(TextField).first, '9111111111');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(login.sends, 1);
    expect(access.codeSent, isFalse);
    expect(find.text('Resend OTP'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await _acceptConsent(tester);
    expect(login.sends, 2);
    expect(login.sentNumbers, ['9000000000', '9111111111']);
    await _close(tester, access);
  });

  testWidgets('rapid explicit resend stays one send during autofill and HTTP', (
    tester,
  ) async {
    final login = _Login()..mockAutofill();
    final access = await _restoreExpiredChallenge(tester, login);
    login.autofillPending = Completer<int>();
    login.sendPending = Completer<http.Response>();
    final resend = find.widgetWithText(TextButton, 'Resend OTP');
    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.tap(resend);
    await tester.pump();
    expect(login.autofillStarts, 2, reason: 'One original and one resend');
    expect(login.sends, 1);
    login.autofillPending!.complete(2);
    await tester.pump();
    await tester.pump();
    expect(login.sends, 2);
    expect(access.busy, isTrue);
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    login.sendPending!.complete(login.challenge());
    await tester.pumpAndSettle();
    expect(login.sends, 2);
    expect(access.codeExpired, isFalse);
    expect(find.text('Resend OTP'), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester, access);
  });
}
