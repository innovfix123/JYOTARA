import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/profile_session.dart';

class UnknownTimeSession extends ProfileSession {
  @override
  Map<String, dynamic>? get facts => {'rashi': 'Meena'};
}

void main() {
  testWidgets(
    'unknown-time chat remains usable and offers an optional time edit',
    (tester) async {
      final session = UnknownTimeSession();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Birth time unknown · General guidance only'),
        findsNothing,
      );
      expect(find.byKey(const Key('chatInput')), findsOneWidget);
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit birth details'));
      await tester.pumpAndSettle();
      expect(find.byType(BirthForm), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'unknown-time life chapters request reflection rather than chart predictions',
    (tester) async {
      final session = UnknownTimeSession();
      await tester.pumpWidget(
        MaterialApp(home: ExploreDetail(kind: 4, session: session)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Birth time unknown · General guidance only'),
        findsOneWidget,
      );
      final chapters = tester.widgetList<ReadingPanel>(
        find.byType(ReadingPanel),
      );
      expect(chapters, hasLength(3));
      for (final chapter in chapters) {
        expect(chapter.question, startsWith('Help me'));
        expect(chapter.question, isNot(contains('birth chart')));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
