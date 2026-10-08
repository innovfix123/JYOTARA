import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets('one chat mode, no timer or per-answer receipt in conversation', (
    tester,
  ) async {
    final session = ProfileSession();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(guide: guides.first, session: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-settings-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Standard'), findsNothing);
    expect(find.text('Detailed'), findsNothing);
    expect(find.textContaining('Coins per answer'), findsNothing);
    expect(find.byKey(const Key('end-chat')), findsOneWidget);
    expect(find.byKey(const Key('chatInput')), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'Back keeps chat open and confirmed End chat returns to previous page',
    (tester) async {
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ChatScreen(guide: guides.first, session: session),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ChatScreen));
      await Navigator.of(context).maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(session.conversation(guides.first.conversationKey).ended, false);
      await tester.tap(find.byKey(const Key('end-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsNothing);
      expect(session.conversation(guides.first.conversationKey).ended, true);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
