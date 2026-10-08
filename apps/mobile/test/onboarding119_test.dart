import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/first_profile_setup.dart';
import 'package:jyotara/premium_onboarding.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets(
    'compact onboarding keeps essential fields and moves optional preferences to Profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FirstProfileSetup(
            session: ProfileSession(),
            child: const Text('Home'),
          ),
        ),
      );
      expect(tester.widget<BirthForm>(find.byType(BirthForm)).onboarding, true);
      expect(find.text('Made for you.'), findsOneWidget);
      expect(find.text('Preferred chatting language'), findsNothing);
      expect(find.text('Relationship status (optional)'), findsNothing);
      expect(find.text('Profession (optional)'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('gender-female')));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('Not known'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'compact form preserves submit data and processing-consent validation',
    (tester) async {
      Map<String, dynamic>? result;
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: BirthForm(
            onboarding: true,
            session: session,
            onSubmit: (value) async {
              result = value;
            },
            onCompleted: () {},
            initialDetails: {
              'nickname': 'Saran',
              'datetime': '2002-07-29T17:00:00+05:30',
              'latitude': 11.0,
              'longitude': 77.0,
              'exactTime': true,
              'birthplaceLabel': 'Erode',
              'relationshipStatus': 'Single',
              'profession': 'Employed',
              'preferredChatLanguage': 'tamil',
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('gender-male')));
      await tester.scrollUntilVisible(
        find.text('Use these birth details'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Use these birth details'));
      await tester.pump();
      expect(result, isNull);
      await tester.ensureVisible(find.byType(Checkbox).last);
      await tester.tap(find.byType(Checkbox).last);
      await tester.scrollUntilVisible(
        find.text('Use these birth details'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Use these birth details'));
      await tester.pumpAndSettle();
      expect(result?['datetime'], '2002-07-29T17:00:00+05:30');
      expect(result?['nickname'], 'Saran');
      expect(result?['preferredChatLanguage'], 'tamil');
      expect(result?['profession'], 'Employed');
      expect(result?['relationshipStatus'], 'Single');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'login keeps Continue visible above a small-phone keyboard and enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async => null,
        write: (_) async {},
        client: MockClient(
          (r) async =>
              http.Response(jsonEncode({'challengeId': 'b' * 48}), 200),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              viewInsets: EdgeInsets.only(bottom: 280),
              textScaler: TextScaler.linear(1.6),
            ),
            child: PhoneAccessScreen(access: access, child: const Text('Home')),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.widgetWithText(FilledButton, 'Continue').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Continue')).bottom,
        lessThanOrEqualTo(360),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    },
  );
  testWidgets('compact birth details scroll safely with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: BirthForm(onboarding: true, session: ProfileSession()),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Continue to Jyotara'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingBackdrop), findsOneWidget);
  });
}
