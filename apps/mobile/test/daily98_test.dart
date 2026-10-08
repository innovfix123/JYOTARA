import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/main.dart' show profileSession;

void main() {
  testWidgets(
    'daily fetches one sign, removes unused sections and hides energy without birth time',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      final old = profileSession.birthTimeKnown;
      profileSession.birthTimeKnown = false;
      addTearDown(() => profileSession.birthTimeKnown = old);
      await tester.pumpWidget(
        MaterialApp(
          home: DailyHoroscopeScreen(
            request: (path, body) async {
              calls.add(Map<String, dynamic>.from(body));
              return {
                'sections': [
                  {'title': 'General', 'text': 'General reading.'},
                  {'title': 'Health', 'text': 'Physical reading.'},
                  {'title': 'Love', 'text': 'Emotional reading.'},
                ],
              };
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls.length, 1);
      expect(find.text('Energy levels'), findsNothing);
      expect(find.text('Add your birth time'), findsOneWidget);
      expect(find.textContaining('12 Rasis'), findsNothing);
      expect(find.textContaining('Ask about'), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.text('Tomorrow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(calls.length, 2);
      expect(calls[0]['date'], isNot(calls[1]['date']));
    },
  );
  testWidgets('daily cards show one sentence per category without scores', (
    tester,
  ) async {
    final old = profileSession.birthTimeKnown;
    profileSession.birthTimeKnown = true;
    addTearDown(() => profileSession.birthTimeKnown = old);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyHoroscopeScreen(
          request: (_, body) async => {
            'sections': [
              {'title': 'General', 'text': 'General guidance.'},
              {'title': 'Career', 'text': 'Mind guidance.'},
              {'title': 'Health', 'text': 'Physical guidance.'},
              {'title': 'Love', 'text': 'Emotional guidance.'},
            ],
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('dailyApproach')));
    await tester.tap(find.byKey(const Key('dailyApproach')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Emotional guidance.'), 250);
    expect(find.text('Emotional guidance.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mind guidance.'), 200);
    expect(find.text('Mind guidance.'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
