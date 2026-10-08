import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/privacy_links.dart';
import 'package:jyotara/services/phone_access.dart';

Widget screen(PhoneAccess access) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(height: 1.48),
      bodyMedium: TextStyle(height: 1.42),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  ),
  home: PhoneAccessScreen(access: access, child: const Text('Signed in')),
);

void phoneSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('JYOT-7/8 login keeps consent and separates reviewer access', (
    tester,
  ) async {
    phoneSize(tester, const Size(360, 800));
    final access = PhoneAccess(testerCode: () => null);
    await tester.pumpWidget(screen(access));
    expect(find.text('Learn how we protect your information'), findsNothing);
    expect(find.text('Account deletion help'), findsNothing);
    expect(find.byType(LoginConsent), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('App reviewer access'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getTopLeft(find.text('OR')).dy,
      greaterThan(tester.getBottomLeft(find.text('Continue')).dy),
    );
    expect(
      tester.getBottomLeft(find.text('OR')).dy,
      lessThan(tester.getTopLeft(find.text('App reviewer access')).dy),
    );
    await tester.tap(find.text('App reviewer access'));
    await tester.pumpAndSettle();
    expect(find.text('Review username'), findsOneWidget);
    expect(find.text('Review password'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });

  testWidgets('JYOT-9 Continue stays above keyboard on small phone', (
    tester,
  ) async {
    phoneSize(tester, const Size(320, 640));
    addTearDown(tester.view.resetViewInsets);
    final access = PhoneAccess(testerCode: () => null);
    await tester.pumpWidget(screen(access));
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.enterText(find.byType(TextField).first, '9000000000');
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Continue');
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(360));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(
      tester.getTopLeft(find.text('OR')).dy,
      greaterThan(tester.getBottomLeft(button).dy),
    );
    expect(
      tester.getTopLeft(find.text('App reviewer access')).dy,
      greaterThan(tester.getBottomLeft(find.text('OR')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });

  testWidgets(
    'JYOT-10/11 OTP fits and expiry becomes Resend without a second timer',
    (tester) async {
      phoneSize(tester, const Size(360, 720));
      var now = DateTime(2026, 10, 6, 12);
      var sends = 0;
      final access = PhoneAccess(
        testerCode: () => null,
        requireRealSms: true,
        now: () => now,
        write: (_) async {},
        client: MockClient((request) async {
          sends++;
          return http.Response(jsonEncode({'challengeId': 'b' * 48}), 200);
        }),
      );
      await access.send('9000000000');
      await tester.pumpWidget(screen(access));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, 0);
      expect(
        find.text('Enter your verification code').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Verify & continue').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Code expires in 5:00'), findsOneWidget);
      expect(find.byType(PrivacyLinks), findsNothing);
      expect(find.text('App reviewer access'), findsNothing);
      expect(find.text('Learn how we protect your information'), findsNothing);
      expect(find.textContaining('Resend in'), findsNothing);
      expect(find.text('Resend OTP'), findsNothing);
      await tester.enterText(find.byType(TextField).last, '123456');
      tester.testTextInput.hide();
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Code expires in 4:00'), findsOneWidget);
      expect(find.text('Resend OTP'), findsNothing);
      now = now.add(const Duration(minutes: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Code expires in'), findsNothing);
      final resend = find.widgetWithText(TextButton, 'Resend OTP');
      expect(resend.hitTestable(), findsOneWidget);
      expect(position.maxScrollExtent, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Verify & continue'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(resend);
      await tester.pumpAndSettle();
      expect(sends, 2);
      expect(find.text('Code expires in 5:00'), findsOneWidget);
      expect(find.byType(PrivacyLinks), findsNothing);
      expect(find.text('App reviewer access'), findsNothing);
      expect(find.text('Learn how we protect your information'), findsNothing);
      expect(find.text('Resend OTP'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    },
  );
}
