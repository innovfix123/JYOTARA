import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/phone_access.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';

class RouteCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  testWidgets('entering home retains the login guard after sign out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final access = PhoneAccess(
      testerCode: () => 'test',
      read: () async => jsonEncode({
        'token': List.filled(64, 'a').join(),
        'accountId': 'one',
        'expiresAt': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      }),
      write: (_) async {},
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await access.restore();
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneAccessScreen(access: access, child: const IntroScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Explore Jyotara'));
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
    await access.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsNothing);
    expect(find.text('Mobile number'), findsOneWidget);
  });

  testWidgets(
    'account shortcut cannot stack account pages and back returns once',
    (tester) async {
      final observer = RouteCounter();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Scaffold(body: HomeScreen(onOpenChat: (_) {})),
        ),
      );
      final initial = observer.pushes;
      await tester.tap(find.byTooltip('Account'));
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(observer.pushes, initial + 1);
      expect(find.text('Your account'), findsOneWidget);
      expect(find.byTooltip('Account'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Account'), findsOneWidget);
      expect(find.text('Your account'), findsNothing);
    },
  );
  testWidgets('account tab never offers a recursive account shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountScreen())),
    );
    expect(find.byTooltip('Account'), findsNothing);
  });
}
