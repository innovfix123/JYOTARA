import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/notification_center.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  for (final language in ['en', 'ta']) {
    testWidgets('notifications stay usable at large text in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = UiLanguagePreferences(write: (_) async {});
      await prefs.set(language);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => UiLanguageScope(
            preferences: prefs,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
          home: const NotificationCenter(),
        ),
      );
      await tester.pumpAndSettle();
      final label = language == 'ta'
          ? tamilUi['Notification settings']!
          : 'Notification settings';
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
}
