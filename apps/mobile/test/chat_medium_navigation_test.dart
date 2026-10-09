import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/conversation.dart';

void main() {
  testWidgets(
    'saved reply type and language reopen collapsed, with menu usable while typing',
    (tester) async {
      final session = ProfileSession();
      session.preferredChatLanguage = 'tanglish';
      session
          .conversation(guides.first.conversationKey)
          .messages
          .add(
            ChatMessage(
              fromUser: false,
              text: guideWelcome(guides.first, '', 'english'),
            ),
          );
      session.conversation(guides.first.conversationKey).depth = 'standard';
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        session.conversation(guides.first.conversationKey).language,
        'tanglish',
      );
      expect(
        session.conversation(guides.first.conversationKey).messages.single.text,
        contains('Naan Meera'),
      );
      expect(find.text('Choose your reply'), findsNothing);
      expect(find.byKey(const ValueKey('reply-tanglish')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'Draft question',
      );
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(PopupMenuItem<String>, 'End chat'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('reopening ended chat starts fresh and exposes saved history', (
    tester,
  ) async {
    final session = ProfileSession();
    final chat = session.conversation(guides.first.conversationKey);
    chat.messages.add(
      const ChatMessage(fromUser: true, text: 'Old private question'),
    );
    chat.ended = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(guide: guides.first, session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(chat.ended, false);
    expect(find.text('Old private question'), findsNothing);
    expect(chat.history.single.single.text, 'Old private question');
    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    expect(find.text('View old chats'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
