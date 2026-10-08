import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/discovery_screens.dart';

void main() {
  testWidgets(
    'city survives reopen and a late restore cannot replace selection',
    (tester) async {
      String? saved;
      final initial = Completer<String?>();
      final queries = <String>[];
      final timings = <Map<String, dynamic>>[];
      Widget screen(Key key, Future<String?> Function() read) => MaterialApp(
        home: DailyHoroscopeScreen(
          key: key,
          readCity: read,
          writeCity: (v) async {
            saved = v;
          },
          pickCity: (_, query) async {
            queries.add(query);
            return [1, 'Perambalur', 'Tamil Nadu', 'India', 0, 0, 11.23, 78.88];
          },
          request: (path, body) async {
            timings.add(body);
            return {
              'sections': [
                {'title': 'General', 'text': 'Today is steady.'},
              ],
              'timings': [],
            };
          },
        ),
      );
      await tester.pumpWidget(screen(const ValueKey(1), () => initial.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Choose current city for timings'),
        200,
      );
      await tester.tap(find.text('Choose current city for timings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('Perambalur, Tamil Nadu'), findsOneWidget);
      initial.complete(jsonEncode({'name': 'Old city', 'lat': 1, 'lon': 2}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('Old city'), findsNothing);
      await tester.tap(find.text('Perambalur, Tamil Nadu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(queries, ['', 'Perambalur, Tamil Nadu']);
      expect(jsonDecode(saved!)['lat'], 11.23);
      await tester.pumpWidget(screen(const ValueKey(2), () async => saved));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Perambalur, Tamil Nadu'), 200);
      expect(find.text('Perambalur, Tamil Nadu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
