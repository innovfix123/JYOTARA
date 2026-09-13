import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/profile_gender.dart';

void main() {
  testWidgets('typing debounces lookup and ignores stale district results', (
    tester,
  ) async {
    final requests = <String, Completer<http.Response>>{};
    final session = ProfileSession(
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((r) {
          final query = jsonDecode(r.body)['query'] as String;
          final response = Completer<http.Response>();
          requests[query] = response;
          return response.future;
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BirthForm(session: session, initialGender: ProfileGender.male),
      ),
    );
    final field = find.byKey(const Key('birthplaceField'));
    await tester.scrollUntilVisible(field, -150, scrollable: find.byType(Scrollable).first);
    await tester.enterText(field, 'Ero');
    await tester.pump(const Duration(milliseconds: 200));
    expect(requests, isEmpty);
    await tester.enterText(field, 'Erode');
    await tester.pump(const Duration(milliseconds: 351));
    expect(requests.keys, ['Erode']);
    await tester.enterText(field, 'Kochi');
    await tester.pump(const Duration(milliseconds: 351));
    http.Response reply(String name) => http.Response(
      jsonEncode({
        'data': [
          [name, name, 'Kerala', '', 'IN', 'Asia/Kolkata', 9.9, 76.2],
        ],
      }),
      200,
    );
    requests['Kochi']!.complete(reply('Kochi'));
    await tester.pumpAndSettle();
    expect(find.text('Kochi, Kerala'), findsOneWidget);
    requests['Erode']!.complete(reply('Erode'));
    await tester.pumpAndSettle();
    expect(find.text('Erode, Kerala'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'selected birthplace survives keyboard search and editing invalidates it',
    (tester) async {
      final queries = <String>[];
      final session = ProfileSession(
        api: JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((r) async {
            queries.add(jsonDecode(r.body)['query'] as String);
            return http.Response(
              jsonEncode({
                'data': [
                  [
                    'erode',
                    'Erode',
                    'Tamil Nadu',
                    '',
                    'IN',
                    'Asia/Kolkata',
                    11.34,
                    77.72,
                  ],
                ],
              }),
              200,
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BirthForm(session: session, initialGender: ProfileGender.male),
        ),
      );
      final field = find.byKey(const Key('birthplaceField'));
      await tester.scrollUntilVisible(field, -150, scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, 'Erode, Tamil Nadu');
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      expect(queries, ['Erode']);
      final result = find.widgetWithText(ListTile, 'Erode, Tamil Nadu');
      await tester.ensureVisible(result);
      await tester.tap(result);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(field, -150, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).decoration!.helperText,
        'Birthplace selected',
      );
      // Both the keyboard Search action and explicit button must preserve selection.
      tester.widget<TextField>(field).onSubmitted!('Erode, Tamil Nadu');
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextButton, 'Search birthplace');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(queries, ['Erode']);
      await tester.scrollUntilVisible(field, -150, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).decoration!.helperText,
        'Birthplace selected',
      );
      await tester.scrollUntilVisible(field, -150, scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, 'Ko');
      await tester.pumpAndSettle();
      expect(find.text('Birthplace selected'), findsNothing);
      expect(
        find.text('Select a birthplace from the search results.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
