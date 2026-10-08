import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets(
    'explicit Tanglish controls greeting without automatic profile request',
    (tester) async {
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            guide: guides.first,
            session: session,
            allowProfileSwitch: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      expect(find.text('Daily'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chatInput')))
            .decoration
            ?.counterText,
        '',
      );
      expect(session.conversation('Meera').messages.length, 1);
      expect(find.textContaining('Meena'), findsNothing);
      expect(find.text('Detailed'), findsNothing);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-settings-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reply-tanglish')));
      await tester.pumpAndSettle();
      expect(session.conversation('Meera').language, 'tanglish');
      expect(
        session.conversation('Meera').messages.single.text,
        contains('Naan Meera'),
      );
      await tester.enterText(find.byKey(const Key('chatInput')), 'hi');
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pumpAndSettle();
      expect(
        session.conversation('Meera').messages.last.text,
        'Vanakkam! Edha pathi pesa virumbureenga?',
      );
      expect(find.byKey(const ValueKey('reply-tanglish')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-settings-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-tanglish')), findsOneWidget);
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      expect(find.text('Change Kundli'), findsOneWidget);
      expect(find.text('End chat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
