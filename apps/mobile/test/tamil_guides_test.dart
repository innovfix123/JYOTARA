import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets('Tamil guide filters keep stable identities and remain readable at double text size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    Guide? opened;
    await tester.pumpWidget(MaterialApp(builder: (context, child) => UiLanguageScope(preferences: ui,
      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!)),
      home: Scaffold(body: GuidesScreen(onOpenChat: (guide) => opened = guide))));
    await tester.pumpAndSettle();
    expect(find.text('துறை சார்ந்த வழிகாட்டிகள்'), findsOneWidget);
    expect(find.text('Specialist guides'), findsNothing);
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, 'தொழில்'), 180,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'தொழில்'));
    await tester.pumpAndSettle();
    final arivan = find.text('அறிவன்');
    await tester.scrollUntilVisible(arivan, 180,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('ஆதிரை'), findsNothing);
    expect(tester.takeException(), null);
    await tester.tap(arivan);
    expect(opened?.name, 'Arivan', reason: 'Displayed Tamil names must not change routing identity');
    await ui.set('en');
    await tester.pumpAndSettle();
    expect(find.text('Arivan'), findsOneWidget);
    expect(find.text('Aadhirai'), findsNothing, reason: 'Changing language retains the active filter');
    expect(tester.takeException(), null);
  });

  testWidgets('Tamil quick ask shows translated names and opens the same guide', (tester) async {
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    Guide? opened;
    await tester.pumpWidget(MaterialApp(builder: (_, child) => UiLanguageScope(preferences: ui, child: child!),
      home: Scaffold(body: QuickAskScreen(onOpenChat: (guide) => opened = guide))));
    await tester.pumpAndSettle();
    expect(find.text('இயல்பாகக் கேளுங்கள்.'), findsOneWidget);
    await tester.tap(find.text('ஆதிரை'));
    expect(opened?.name, 'Aadhirai');
    expect(tester.takeException(), null);
  });
}
