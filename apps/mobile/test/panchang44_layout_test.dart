import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets(
    'Panchang place label does not overlap search at large Tamil text',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ui = UiLanguagePreferences(write: (_) async {});
      await ui.set('ta');
      final session = ProfileSession()
        ..birthplaceLabel = 'Perambalur, Tamil Nadu';
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: ui,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.6),
              ),
              child: ExploreDetail(kind: 1, session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = find.textContaining('Perambalur');
      final search = find.widgetWithIcon(OutlinedButton, Icons.place_outlined);
      expect(label, findsOneWidget);
      expect(search, findsOneWidget);
      expect(
        tester.getRect(label).bottom,
        lessThan(tester.getRect(search).top),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
