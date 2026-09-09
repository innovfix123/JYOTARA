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
