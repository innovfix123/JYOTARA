import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/services/profile_session.dart';

class PeriodSession extends ProfileSession {
  PeriodSession() { birthTimeKnown = true; }
  @override
  Map<String,dynamic>? get facts => {'rashi':'Meena'};
  @override
  List<Map<String,dynamic>> get dashaTimeline => [{'name':'Saturn','start':'2020-01-01T00:00:00Z','end':'2040-01-01T00:00:00Z','antardasha':[{'name':'Mercury','start':'2020-01-01T00:00:00Z','end':'2040-01-01T00:00:00Z'}]}];
}
void main() {
  testWidgets('houses and planets expand to real explanations', (tester) async {
    for (final kind in ['houses','planets']) {
      await tester.pumpWidget(MaterialApp(home: ExploreQuickPage(kind:kind, session:ProfileSession())));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text(kind=='houses'?'Your identity and the way you approach life.':'Identity, confidence and how you take responsibility.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('current Dasha and Bhukti explain from saved chart without reading request', (tester) async {
    await tester.pumpWidget(MaterialApp(home:ExploreDetail(kind:3,session:PeriodSession())));
    await tester.pumpAndSettle();
    expect(find.text('Your current Dasha'),findsOneWidget);
    expect(find.textContaining('Patience, responsibilities'), findsOneWidget);
    expect(find.textContaining('Learning, thinking'), findsOneWidget);
    expect(find.text('My period reading'),findsNothing);
    expect(find.text('Open reading'),findsNothing);
  });
}
