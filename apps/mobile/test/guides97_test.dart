import 'package:jyotara/services/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  test('approved lineup has ten distinct portraits and category counts', () {
    expect(guides.length, 10);
    expect(guides.map((g) => g.name).toSet().length, 10);
    expect(guides.map((g) => g.portraitIndex).toSet(), Set.of(List.generate(10, (i) => i)));
    expect(guides.where((g) => g.group == 'Love & Marriage').length, 4);
    for (final group in ['Education & Hobbies', 'Career & Business', 'Family & Personal Life']) {
      expect(guides.where((g) => g.group == group).length, 2);
    }
    expect(guides.singleWhere((g) => g.name == 'Nila').conversationKey,
        isNot(legacyGuides.singleWhere((g) => g.name == 'Nila').conversationKey));
  });
  testWidgets('category filters show their own approved profiles and open correct guide', (tester) async {
    Guide? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GuidesScreen(onOpenChat: (g) => selected = g))));
    await tester.pumpAndSettle();
    for (final pair in [('Education & Hobbies', 'Aravind'), ('Career & Business', 'Adithya'), ('Family & Personal Life', 'Revathi'), ('Love & Marriage', 'Meera')]) {
      await tester.ensureVisible(find.text(pair.$1));
      await tester.tap(find.text(pair.$1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(pair.$2));
      await tester.tap(find.text(pair.$2));
      expect(selected?.name, pair.$2);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('all portraits and welcomes render, old Nila conversation stays separate', (tester) async {
    final session = ProfileSession();
    session.conversation('Nila').messages.add(const ChatMessage(fromUser: true, text: 'Old family chat'));
    for (final guide in guides) {
      await tester.pumpWidget(MaterialApp(home: ChatScreen(key: ValueKey(guide.name), guide: guide, session: session)));
      await tester.pumpAndSettle();
      expect(find.textContaining('I’m ${guide.name}.'), findsOneWidget);
      expect(find.text('Old family chat'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(session.conversation('Nila').messages.single.text, 'Old family chat');
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
