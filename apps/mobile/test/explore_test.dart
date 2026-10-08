import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';

void main() {
  test('dasha intervals select only one period at boundary', () {
    final first = {
      'start': '2026-01-01T00:00:00Z',
      'end': '2026-09-01T00:00:00Z',
    };
    final second = {
      'start': '2026-09-01T00:00:00Z',
      'end': '2027-01-01T00:00:00Z',
    };
    final now = DateTime.parse('2026-09-01T00:00:00Z');
    expect(activePeriod(first, now), false);
    expect(activePeriod(second, now), true);
    expect(activePeriod({'start': 'bad', 'end': 'bad'}, now), false);
    expect(calendarTime('2026-09-01T00:00:00Z'), '2026-09-01 · 05:30 IST');
  });
  testWidgets(
    'Explore library and personal tools remain accessible at large text scale',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: const Scaffold(body: ExploreScreen()),
          ),
        ),
      );
      expect(find.text('Explore astrology'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Know myself'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Know myself'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Tamil Explore remains readable at enlarged text', (
    tester,
  ) async {
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    await tester.pumpWidget(
      UiLanguageScope(
        preferences: ui,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: const Scaffold(body: ExploreScreen()),
          ),
        ),
      ),
    );
    expect(find.text('ஜோதிடம் அறிவோம்'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('என்னைப் பற்றி'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing chart asks for birth details without starting AI', (
    tester,
  ) async {
    final session = ProfileSession(
      vault: LocalProfileVault(read: () async => null, write: (_) async {}),
    );
    await tester.pumpWidget(
      MaterialApp(home: ExploreDetail(kind: 4, session: session)),
    );
    expect(find.text('Add birth details'), findsOneWidget);
    expect(find.text('Open reading'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
