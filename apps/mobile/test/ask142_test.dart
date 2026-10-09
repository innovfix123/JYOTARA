import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/ask_theme.dart';
import 'package:jyotara/bronze_theme.dart';
import 'package:jyotara/chat_wallpaper.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets('compact guide CTA opens its existing identity without a score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Guide? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: MainTabScope(
              child: GuidesScreen(onOpenChat: (guide) => opened = guide),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('guide-card-Meera'));
    final cta = find.byKey(const ValueKey('guide-chat-Meera'));
    expect(tester.getSize(card).height, lessThan(125));
    expect(tester.getSize(cta).height, greaterThanOrEqualTo(44));
    expect(
      find.descendant(of: card, matching: find.text('தமிழ், English')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('No ratings yet')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.star_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(guides.first.speciality)),
      findsNothing,
    );
    expect(find.text('4.8'), findsNothing);
    expect(find.text('4.9'), findsNothing);
    expect(tester.widget<Card>(card).color, AskPalette.card);
    expect(
      Theme.of(tester.element(cta)).textTheme.bodyMedium?.fontFamily,
      'JyotaraSans',
    );
    await tester.tap(cta);
    expect(opened, same(guides.first));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Tamil cards and filters remain usable at 320px and double text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = UiLanguagePreferences(write: (_) async {});
      await language.set('ta');
      Guide? opened;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => UiLanguageScope(
            preferences: language,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: MainTabScope(
              child: GuidesScreen(onOpenChat: (guide) => opened = guide),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI வழிகாட்டிகள்'), findsOneWidget);
      final chip = find.widgetWithText(ChoiceChip, 'வேலை & தொழில்');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      final guide = guides.firstWhere(
        (guide) => guide.group == 'Career & Business',
      );
      final cta = find.byKey(ValueKey('guide-chat-${guide.name}'));
      await tester.ensureVisible(cta);
      expect(find.text('பேசு'), findsWidgets);
      expect(find.text('மதிப்பீடுகள் இல்லை'), findsWidgets);
      await tester.tap(cta);
      expect(opened, same(guide));
      expect(find.byKey(const ValueKey('guide-card-Meera')), findsNothing);
      await language.set('en');
      await tester.pumpAndSettle();
      expect(find.text(guide.name), findsOneWidget);
      expect(find.byKey(const ValueKey('guide-card-Meera')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conversation has Roboto, soft bubbles and the saved messages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = ProfileSession();
    final chat = session.conversation(guides.first.conversationKey);
    chat.messages.addAll(const [
      ChatMessage(fromUser: false, text: 'A saved guide reply.'),
      ChatMessage(fromUser: true, text: 'A saved question.'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(guide: guides.first, session: session),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('chatInput'));
    expect(
      Theme.of(tester.element(input)).textTheme.bodyMedium?.fontFamily,
      'JyotaraChat',
    );
    expect(find.text('AI guide'), findsOneWidget);
    expect(find.text('A saved guide reply.'), findsOneWidget);
    expect(find.text('A saved question.'), findsOneWidget);
    expect(
      tester
          .widget<Material>(find.byKey(const Key('softBronzeConversation')))
          .color,
      AskPalette.conversation,
    );
    expect(find.byType(ChatWallpaper), findsOneWidget);
    await tester.enterText(input, 'Draft to retain');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(input).dy, lessThanOrEqualTo(360));
    expect(tester.widget<TextField>(input).controller?.text, 'Draft to retain');
    expect(chat.messages.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test('Ask styles are local and preserve the base palette', () {
    final base = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: BronzePalette.background,
    );
    expect(askTheme(base).scaffoldBackgroundColor, AskPalette.background);
    expect(
      askTheme(base, conversation: true).scaffoldBackgroundColor,
      AskPalette.conversation,
    );
    expect(base.scaffoldBackgroundColor, BronzePalette.background);
  });
}
