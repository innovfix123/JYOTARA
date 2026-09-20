import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/chat_availability.dart';

void main() {
  testWidgets('public chat gate explains free access on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ChatUnavailableScreen()));
    expect(find.text('Something thoughtful is on its way'), findsOneWidget);
    expect(
      find.text(
        'Daily horoscopes, Free Kundli and Kundli Matching are still available.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
