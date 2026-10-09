import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/chat_delivery.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  test(
    'paragraph bubbles preserve all English, Tamil and Tanglish content',
    () {
      for (final answer in [
        'Your Moon is in Meena. Take your time with this conversation.\n\nListen before replying.',
        'உங்கள் உணர்வுகளை நிதானமாகச் சொல்லுங்கள். பதில் சொல்லும் முன் கேளுங்கள்.\n\nஅவசரம் வேண்டாம்.',
        'Nidhanama pesunga. Avanga solradha kelunga.\n\nOru step-aa pogalam.',
        '1. Talk with Dr. Meera. 2. Your score is 18.5 out of 36.',
        '${List.filled(55, 'patiently').join(' ')}.',
      ]) {
        final parts = chatReplyParts(answer);
        expect(
          parts.join(' ').replaceAll(RegExp(r'\s+'), ' '),
          answer.replaceAll(RegExp(r'\s+'), ' '),
        );
        expect(parts.every((s) => s.trim().isNotEmpty), true);
      }
      expect(chatReplyParts('Score: 18.5 / 36.'), ['Score: 18.5 / 36.']);
    },
  );

  test('sentences stay in their paragraph; legacy replies have at most five groups', () {
    final paragraphs = List.generate(
      12,
      (index) =>
          'Thought $index. Its explanation stays here. Its next step stays here.',
    );
    expect(chatReplyParts(paragraphs.take(4).join('\n\n')), paragraphs.take(4));
    final parts = chatReplyParts(paragraphs.join('\n\n'));
    expect(parts, hasLength(5));
    expect(parts.expand((part) => part.split('\n\n')), paragraphs);
    expect(chatReplyParts(' \n\n '), isEmpty);
  });

  test('more bubbles never accelerate typing or split complete thoughts', () {
    expect(
      chatPartPause('A complete thought.', 3),
      chatPartPause('A complete thought.', 30),
    );
    expect(
      chatPartPause('A complete thought.', 30).inMilliseconds,
      greaterThanOrEqualTo(5000),
    );
    final thought = '${List.filled(45, 'patiently').join(' ')}.';
    expect(chatReplyParts(thought), [thought]);
  });

  testWidgets(
    'new answer reveals in sequence, stored answer and receipt stay intact',
    (tester) async {
      final session = ProfileSession();
      final chat = session.conversation(guides.first.conversationKey);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: session),
        ),
      );
      await tester.pumpAndSettle();
      final answer = ChatMessage(
        fromUser: false,
        text: 'Take your time.\n\nListen patiently.\n\nShare how you feel.',
        label: 'CHART GUIDANCE',
        wallet: {'status': 'complete', 'chargedCoins': 15},
      );
      chat.messages.add(answer);
      chat.changed();
      await tester.pump();
      expect(find.text('Take your time.'), findsOneWidget);
      expect(find.text('Listen patiently.'), findsNothing);
      expect(find.byKey(const Key('chatTypingIndicator')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Take your time.'), findsOneWidget);
      expect(find.text('Listen patiently.'), findsNothing);
      await tester.pump(
        chatPartPause('Listen patiently.', 3) - const Duration(seconds: 4),
      );
      expect(find.text('Listen patiently.'), findsOneWidget);
      expect(find.text('Share how you feel.'), findsNothing);
      await tester.pump(chatPartPause('Share how you feel.', 3));
      expect(find.text('Share how you feel.'), findsOneWidget);
      expect(find.byKey(const Key('chatTypingIndicator')), findsNothing);
      expect(chat.messages.last, same(answer));
      expect(chat.messages.where((m) => identical(m, answer)).length, 1);
      expect(answer.wallet?['chargedCoins'], 15);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share how you feel.'), findsOneWidget);
      expect(find.byKey(const Key('chatTypingIndicator')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'reduced motion displays a complete answer without a typing delay',
    (tester) async {
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: ChatScreen(guide: guides.first, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      session
          .conversation(guides.first.conversationKey)
          .messages
          .add(
            const ChatMessage(
              fromUser: false,
              text: 'First answer.\n\nSecond answer.',
            ),
          );
      session.conversation(guides.first.conversationKey).changed();
      await tester.pump();
      await tester.pump();
      expect(find.text('Second answer.'), findsOneWidget);
      expect(find.byKey(const Key('chatTypingIndicator')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
