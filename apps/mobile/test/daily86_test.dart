import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  test('themes come from supplied content and summaries stay short', () {
    expect(dailyTheme({'sections': [{'text': 'Take time for family.'}]}, true), 'குடும்பம்');
    expect(dailyTheme({'sections': []}, false), 'Daily reading');
    expect(dailyShortText('Take a pause. A long explanation follows.'), 'Take a pause.');
  });
  testWidgets('language switch refreshes source and obsolete responses cannot replace it', (tester) async {
    final old = Completer<Map<String, dynamic>>();
    final ui = UiLanguagePreferences(write: (_) async {});
    await tester.pumpWidget(UiLanguageScope(preferences: ui, child: MaterialApp(home: DailyHoroscopeScreen(request: (_, body) async {
      if (body['language'] == 'en') return old.future;
      return {'sections': [{'title':'General', 'text':'குடும்பத்துடன் பேசுங்கள்.'}]};
    }))));
    await tester.pump();
    await tester.tap(find.text('தமிழ்'));
    await tester.pumpAndSettle();
    old.complete({'sections':[{'title':'General','text':'Obsolete English.'}]});
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('குடும்பத்துடன் பேசுங்கள்.'), 100);
    expect(find.text('Obsolete English.'), findsNothing);
    expect(find.text('குடும்பத்துடன் பேசுங்கள்.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tamil overview uses source themes and selected sign gets a Tamil reading', (tester) async {
    final calls = <Map<String, dynamic>>[];
    final ui = UiLanguagePreferences(write: (_) async {});
    await ui.set('ta');
    await tester.pumpWidget(UiLanguageScope(preferences: ui, child: MaterialApp(home: DailyHoroscopeScreen(request: (_, body) async {
      calls.add(Map.of(body));
      return {'sections': [{'title': 'General', 'text': body['language'] == 'ta' ? 'தமிழ் ${body['sign']}.' : 'Make time for family.'}]};
    }))));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c['language'] == 'ta').length, 1);
    expect(calls.length, 12);
    await tester.scrollUntilVisible(find.text('ரிஷபம்'), 200);
    await tester.ensureVisible(find.text('ரிஷபம்'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ரிஷபம்'));
    await tester.pumpAndSettle();
    expect(calls.last['sign'], 'taurus');
    expect(calls.last['language'], 'ta');
    await tester.scrollUntilVisible(find.text('தமிழ் taurus.'), 100);
    expect(find.text('தமிழ் taurus.'), findsOneWidget);
    expect(find.text('Make time for family.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
