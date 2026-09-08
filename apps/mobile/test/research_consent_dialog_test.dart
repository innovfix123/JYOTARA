import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/research_consent_dialog.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets(
    'privacy language does not opt in; enlarged Tamil control remains usable',
    (tester) async {
      final session = ProfileSession();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(2),
            ),
            child: ResearchConsentDialog(session: session),
          ),
        ),
      );
      expect(session.researchConsent, false);
      await tester.tap(find.text('தமிழ்'));
      await tester.pumpAndSettle();
      expect(find.text('விருப்ப ஆய்வு அனுமதி'), findsOneWidget);
      expect(session.researchConsent, false);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(session.researchConsent, true);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(session.researchConsent, false);
      expect(tester.takeException(), isNull);
    },
  );
}
