import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/main.dart' show accountStorage;
import 'package:jyotara/services/matching_rasi.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets(
    'legacy Rasi failure is visible and explicit retry persists actual sign',
    (tester) async {
      final person = <String, dynamic>{
        'nickname': 'Fixture person',
        'datetime': '2001-09-16T12:00:00+05:30',
        'latitude': 11.0,
        'longitude': 77.0,
        'exactTime': false,
        'birthplaceLabel': 'Fixture place',
      };
      accountStorage.account = 'rasi143-fixture';
      final storageKey = accountStorage.key('jyotara.matching.people.v1');
      FlutterSecureStorage.setMockInitialValues({
        storageKey: jsonEncode([person]),
      });
      addTearDown(() => accountStorage.account = null);
      final replies = <Completer<String?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MatchingScreen(
            loadKundlis: () async => [],
            resolveRasi: (_) {
              final reply = Completer<String?>();
              replies.add(reply);
              return reply.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('matching-second'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('matching-local-${matchingBirthKey(person)}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading Rasi…'), findsOneWidget);
      replies.first.completeError(StateError('Fixture provider failure'));
      await tester.pumpAndSettle();
      expect(find.text('Rasi unavailable'), findsOneWidget);
      final retry = find.byKey(const ValueKey('matching-rasi-retry-false'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(replies.length, 2);
      expect(find.text('Loading Rasi…'), findsOneWidget);
      replies.last.complete('Mesha');
      await tester.pumpAndSettle();
      expect(find.textContaining('Mesha Rasi'), findsOneWidget);
      expect(find.text('Rasi unavailable'), findsNothing);
      final saved = jsonDecode(
        (await KundliLibrary.storage.read(key: storageKey))!,
      ) as List;
      expect(saved.single['calculatedRasi'], 'Mesha');
      expect(saved.single['rasiBirthKey'], matchingBirthKey(person));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rasi retry after account switch clears stale selection without writing it',
    (tester) async {
      final firstPerson = <String, dynamic>{
        'nickname': 'Account A person',
        'datetime': '2001-09-16T12:00:00+05:30',
        'latitude': 11.0,
        'longitude': 77.0,
        'exactTime': false,
      };
      final secondPerson = <String, dynamic>{
        'nickname': 'Account B person',
        'datetime': '2002-07-29T05:00:00+05:30',
        'latitude': 12.0,
        'longitude': 78.0,
        'exactTime': true,
      };
      accountStorage.account = 'rasi143-account-a';
      final firstKey = accountStorage.key('jyotara.matching.people.v1');
      final firstRecord = jsonEncode([firstPerson]);
      accountStorage.account = 'rasi143-account-b';
      final secondKey = accountStorage.key('jyotara.matching.people.v1');
      final secondRecord = jsonEncode([secondPerson]);
      FlutterSecureStorage.setMockInitialValues({
        firstKey: firstRecord,
        secondKey: secondRecord,
      });
      accountStorage.account = 'rasi143-account-a';
      addTearDown(() => accountStorage.account = null);
      final replies = <Completer<String?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MatchingScreen(
            loadKundlis: () async => [],
            resolveRasi: (_) {
              final reply = Completer<String?>();
              replies.add(reply);
              return reply.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('matching-second'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('matching-local-${matchingBirthKey(firstPerson)}')),
      );
      await tester.pumpAndSettle();
      replies.single.completeError(StateError('Fixture provider failure'));
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('matching-rasi-retry-false'));
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);

      accountStorage.account = 'rasi143-account-b';
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(replies, hasLength(1));
      expect(retry, findsNothing);
      expect(
        find.byKey(const ValueKey('matching-delete-selected-second')),
        findsNothing,
      );
      expect(await KundliLibrary.storage.read(key: firstKey), firstRecord);
      expect(await KundliLibrary.storage.read(key: secondKey), secondRecord);

      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('matching-local-${matchingBirthKey(firstPerson)}')),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey('matching-local-${matchingBirthKey(secondPerson)}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
