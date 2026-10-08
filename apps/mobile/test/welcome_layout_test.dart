import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/welcome_design.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  testWidgets('Animated welcome supports reduced motion and entry', (
    tester,
  ) async {
    var entered = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            disableAnimations: true,
            textScaler: TextScaler.linear(1.8),
          ),
          child: AnimatedWelcomePage(onEnter: () => entered = true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('enterApp')), 150);
    await tester.tap(find.byKey(const Key('enterApp')));
    expect(entered, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.8]) {
    testWidgets('Phone welcome is usable at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const JyotaraApp());
      final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async => null,
        write: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: PhoneAccessScreen(access: access, child: const SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jyotara'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Send OTP'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    });
  }
}
