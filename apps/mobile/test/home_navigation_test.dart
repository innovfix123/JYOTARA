import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  for (final language in ['en', 'ta']) {
    testWidgets(
      'Home controls and honest daily state in $language at large text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ui = UiLanguagePreferences(write: (_) async {});
        await ui.set(language);
        String text(String value) =>
            language == 'ta' ? tamilUi[value] ?? value : value;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => UiLanguageScope(
              preferences: ui,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
            home: Scaffold(body: HomeScreen(onOpenChat: (_) {})),
          ),
        );
        await tester.tap(find.byTooltip(text('Account')));
        await tester.pumpAndSettle();
        expect(find.byType(AccountScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(text('View all')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(text('View all')));
        await tester.pumpAndSettle();
        expect(find.byType(GuidesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        const disclaimer =
            'Daily timings are not connected on this screen yet. Your birth chart is not today’s Panchangam. No daily timings are being shown.';
        await tester.scrollUntilVisible(
          find.text(text(disclaimer)),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(text(disclaimer)), findsOneWidget);
        expect(find.text('SET LOCATION'), findsNothing);
        expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
