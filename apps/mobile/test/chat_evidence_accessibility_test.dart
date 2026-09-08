import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/guidance_message.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  testWidgets('long Tamil evidence remains complete and selectable at enlarged text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facts = List.generate(19, (i) => 'சோதனை விவரம் ${i + 1}: கணக்கிடப்பட்ட தகவல்');
    final message = guidanceMessage(GuidanceResponse(
      answer: 'இது சோதனைப் பதில் மட்டுமே. உண்மையான பயனருக்கான பலன் அல்ல.',
      evidence: facts, support: 'partially_supported', answerMode: 'reviewed_traditional',
      limitation: 'சோதனை வரம்பு',
    ), 'tamil');
    final session = ProfileSession();
    session.conversation(guides[1].name).messages.add(message);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: ChatScreen(guide: guides[1], session: session),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byKey(const Key('chatHistoryList')), const Offset(0, -400));
    await tester.pumpAndSettle();
    final answer = tester.widget<Text>(find.text(message.text));
    expect(answer.style?.fontSize, 16);
    for (final fact in facts) {
      expect(answer.data, contains(fact));
    }
    expect(find.ancestor(of: find.text(message.text), matching: find.byType(SelectionArea)), findsOneWidget);
    expect(tester.widget<Text>(find.text(message.label!)).style?.fontSize, 14);
    await tester.drag(find.byKey(const Key('chatHistoryList')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
