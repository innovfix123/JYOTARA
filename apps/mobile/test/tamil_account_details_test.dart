import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets('Tamil account details and reply selector remain usable at enlarged text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    await tester.pumpWidget(MaterialApp(builder: (context, child) => UiLanguageScope(preferences: ui,
      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!)),
      home: const Scaffold(body: AccountScreen())));
    for (final entry in {
      'திட்டங்கள் மற்றும் மீதமுள்ள கேள்விகள்': 'பயன்பாட்டு வரம்புகளைச் சோதனைச் சேவை',
      'உரையாடல் வரலாறு': 'உங்கள் பிறப்பு விவரங்களும் உரையாடல்களும்',
      'இந்தப் பதிப்பு பற்றி': 'Jyotara ஒரு உள் சோதனைப் பதிப்பு',
    }.entries) {
      await tester.scrollUntilVisible(find.text(entry.key), 160);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(entry.value)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('மூடு'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('பதில் மொழி'), -180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('பதில் மொழி'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(SimpleDialog), matching: find.text('பதில் மொழி')), findsOneWidget);
    expect(find.textContaining('தானாக'), findsOneWidget);
    expect(find.text('தங்கிலீஷ்'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Dismiss without changing the global persisted reply preference.
    Navigator.of(tester.element(find.byType(SimpleDialog))).pop();
    await tester.pumpAndSettle();
    await ui.set('en');
    await tester.pumpAndSettle();
    expect(find.text('Chat language'), findsOneWidget);
  });
}
