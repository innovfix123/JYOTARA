import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';

void main() {
  for (final choice in ['standard', 'detailed', 'cancel']) {
    testWidgets('reply picker returns $choice without losing the draft', (tester) async {
      String? selected;
      final draft = TextEditingController(text: 'How is my career?');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => Column(children: [
        TextField(controller: draft),
        TextButton(onPressed: () async { selected = await showChatDepthPicker(context); }, child: const Text('Send')),
      ])))));
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your reply'), findsOneWidget);
      await tester.tap(choice == 'cancel' ? find.text('Cancel') : find.byKey(Key('choose-$choice')));
      await tester.pumpAndSettle();
      expect(selected, choice == 'cancel' ? isNull : choice);
      expect(draft.text, 'How is my career?');
      await tester.pumpWidget(const SizedBox());
      draft.dispose();
    });
  }
}
