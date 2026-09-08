import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets('Tamil chat controls keep English reply preference and history unchanged', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    final session = ProfileSession();
    session.conversation(guides.first.name);
    await session.setChatLanguage('english');
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => UiLanguageScope(preferences: ui,
        child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!)),
      home: ChatScreen(guide: guides.first, session: session),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ஆதிரை'), findsOneWidget);
    expect(find.text('தொடங்க உங்கள் ஜாதகத்தை உருவாக்கவும்'), findsOneWidget);
    expect(find.byTooltip('கேள்வியை அனுப்புங்கள்'), findsOneWidget);
    final input = tester.widget<TextField>(find.byKey(const Key('chatInput')));
    expect(input.decoration?.hintText, 'ஆங்கிலம், தமிழ் அல்லது தங்கிலீஷில் கேளுங்கள்…');
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'ஆங்கிலம்')).selected, isTrue);
    final original = session.conversation(guides.first.name).messages.map((m) => m.text).toList();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'The composer must remain usable with the keyboard and enlarged text');
    expect(tester.getBottomRight(find.byKey(const Key('chatInput'))).dy, lessThanOrEqualTo(544));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await ui.set('en');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send question'), findsOneWidget);
    expect(find.text('Aadhirai'), findsOneWidget);
    expect(session.conversation(guides.first.name).messages.map((m) => m.text).toList(), original);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'English')).selected, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
