import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/research_consent_dialog.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets(
    'optional research explicitly covers future questions and replies and starts off',
    (tester) async {
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResearchConsentDialog(session: session)),
        ),
      );
      expect(
        find.text('Share future questions and replies for research'),
        findsOneWidget,
      );
      expect(find.textContaining('stored encrypted'), findsOneWidget);
      expect(
        find.textContaining('Delete the connected birth profile'),
        findsOneWidget,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(session.researchConsent, true);
      await tester.ensureVisible(find.text('தமிழ்'));
      await tester.tap(find.text('தமிழ்'));
      await tester.pump();
      expect(
        find.text(
          'இனி வரும் கேள்விகளையும் பதில்களையும் ஆய்விற்குப் பகிர்கிறேன்',
        ),
        findsOneWidget,
      );
    },
  );
}
