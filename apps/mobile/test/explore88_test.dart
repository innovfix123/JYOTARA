import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  testWidgets('Tamil planet discovery is concise and local', (tester) async {
    final session = ProfileSession();
    final language = UiLanguagePreferences(write: (_) async {});
    await language.set('ta');
    await tester.pumpWidget(
      UiLanguageScope(
        preferences: language,
        child: MaterialApp(
          home: ExploreQuickPage(kind: 'planets', session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('சூரியன் · தனித்தன்மை'), findsOneWidget);
    expect(find.text('Open reading'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('Rasi with no saved chart never invents a sign', (tester) async {
    final session = ProfileSession();
    await tester.pumpWidget(
      MaterialApp(
        home: ExploreQuickPage(kind: 'rasi', session: session),
      ),
    );
    expect(find.text('Add birth details'), findsOneWidget);
    expect(find.text('Meena'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
