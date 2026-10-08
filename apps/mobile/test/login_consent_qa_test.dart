import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/privacy_links.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  testWidgets('phone login sends no OTP until consent is selected', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('jyotara/otp-autofill'), (call) async => call.method == 'start' ? 1 : null);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('jyotara/otp-autofill'), null));
    var requests = 0;
    final access = PhoneAccess(
      testerCode: () => null,
      requireRealSms: true,
      read: () async => null,
      write: (_) async {},
      client: MockClient((request) async {
        requests++;
        return http.Response(jsonEncode({'challengeId': 'b' * 48}), 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: PhoneAccessScreen(
      access: access, child: const Text('Signed in'),
    )));
    await tester.enterText(find.byType(TextField).first, '9000000000');
    tester.testTextInput.hide();
    await tester.pump();
    final button = find.widgetWithText(FilledButton, 'Continue');
    await tester.scrollUntilVisible(button, 150,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(requests, 0);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(access.codeSent, isTrue);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });

  testWidgets('consent wraps without overflow and links point to separate pages', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: Size(320, 800), textScaler: TextScaler.linear(2)),
      child: Scaffold(body: Padding(padding: const EdgeInsets.all(24),
        child: LoginConsent(value: false, onChanged: (_) {}, openPage: opened.add),
      )),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final rich = tester.widget<RichText>(find.descendant(of: find.byType(LoginConsent), matching: find.byType(RichText)));
    Iterable<TextSpan> flatten(InlineSpan span) sync* {
      if (span is TextSpan) {
        yield span;
        for (final child in span.children ?? <InlineSpan>[]) {
          yield* flatten(child);
        }
      }
    }
    final spans = flatten(rich.text);
    for (final label in ['Terms & Conditions', 'Privacy Policy']) {
      final span = spans.singleWhere((s) => s.text == label);
      (span.recognizer as TapGestureRecognizer).onTap!();
    }
    expect(opened, ['/terms', '/privacy']);
  });
}
