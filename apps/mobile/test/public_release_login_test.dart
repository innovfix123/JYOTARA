import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/phone_access_screen.dart';

void main() {
  testWidgets('public release requires phone login without tester invitation', (tester) async {
    tester.view.physicalSize=const Size(1080,2400);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JyotaraApp());
    await tester.pump(const Duration(seconds:4));
    await tester.pump(const Duration(seconds:1));
    expect(find.byType(PhoneAccessScreen),findsOneWidget);
    expect(find.text('Mobile number'),findsOneWidget);
    expect(find.byType(MainShell),findsNothing);
    await tester.pumpWidget(const SizedBox());
  },skip:!const bool.fromEnvironment('JYOTARA_REQUIRE_PHONE_AUTH') || const bool.fromEnvironment('JYOTARA_REQUIRE_TESTER_ACCESS'));
}
