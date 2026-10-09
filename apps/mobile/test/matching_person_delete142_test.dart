import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/main.dart' show accountStorage;
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

import 'profile_replacement_test.dart' show chartReply;

Future<SavedKundli> savedPerson(String id, String name, String date) async {
  final session = ProfileSession(
    api: JyotaraApiClient(
      baseUrl: 'https://fixture.test',
      client: MockClient((_) async => chartReply(id)),
    ),
  );
  await session.calculate(
    dateTime: '${date}T05:00:00+05:30',
    latitude: 11,
    longitude: 77,
    exactTime: true,
    nickname: name,
    birthplaceLabel: 'Erode',
  );
  return SavedKundli(id, session);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    accountStorage.account = 'matching-delete-account';
  });
  tearDown(() => accountStorage.account = null);

  Future<void> openMatching(
    WidgetTester tester, {
    required List<SavedKundli> saved,
    required Future<void> Function(SavedKundli, List<SavedKundli>) remove,
    Future<List<SavedKundli>> Function()? load,
    String language = 'en',
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = UiLanguagePreferences(write: (_) async {});
    await preferences.set(language);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UiLanguageScope(
          preferences: preferences,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
        ),
        home: MatchingScreen(
          loadKundlis: load ?? () async => List.of(saved),
          removeKundli: remove,
          resolveRasi: (_) async => null,
          request: (_, _) =>
              throw StateError('Deletion must not request a match'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, bool first, String id) async {
    final card = find.byKey(
      ValueKey(first ? 'matching-first' : 'matching-second'),
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ValueKey('matching-saved-$id')));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byKey(ValueKey('matching-saved-$id')),
            matching: find.byType(Text),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ta']) {
    testWidgets(
      'visible saved-person delete clears only its selection in $language',
      (tester) async {
        final first = await savedPerson('one', 'Saran', '2002-07-29');
        final second = await savedPerson('two', 'Shakthi', '2001-09-16');
        addTearDown(first.session.dispose);
        addTearDown(second.session.dispose);
        final saved = [first, second];
        var calls = 0;
        await openMatching(
          tester,
          saved: saved,
          language: language,
          remove: (row, rows) async {
            calls++;
            expect(row, same(first));
            expect(rows.map((r) => r.id), ['one', 'two']);
            saved.removeWhere((r) => r.id == row.id);
          },
        );
        await choose(tester, true, 'one');
        await choose(tester, false, 'two');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        final deletion = find.byKey(
          const ValueKey('matching-delete-selected-first'),
        );
        await tester.ensureVisible(deletion);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: deletion,
            matching: find.text(
              language == 'ta' ? 'நபரை நீக்கு' : 'Delete person',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(deletion);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Saran'),
          ),
          findsWidgets,
        );
        await confirm(
          tester,
          language == 'ta' ? 'நபரை நீக்கு' : 'Delete person',
        );
        expect(calls, 1);
        expect(saved, [second]);
        expect(
          find.byKey(const ValueKey('matching-delete-selected-first')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('matching-delete-selected-second')),
          findsOneWidget,
        );
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse,
        );
        final card = find.byKey(const ValueKey('matching-first'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('matching-saved-one')), findsNothing);
        expect(
          find.byKey(const ValueKey('matching-saved-two')),
          findsOneWidget,
        );
        final otherDelete = find.byKey(const ValueKey('matching-delete-two'));
        expect(
          find.descendant(
            of: otherDelete,
            matching: find.text(language == 'ta' ? 'நீக்கு' : 'Delete'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'canceling picker deletion keeps the saved person and selected consent',
    (tester) async {
      final first = await savedPerson('one', 'Saran', '2002-07-29');
      addTearDown(first.session.dispose);
      final saved = [first];
      var calls = 0;
      await openMatching(tester, saved: saved, remove: (_, _) async => calls++);
      await choose(tester, true, 'one');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final card = find.byKey(const ValueKey('matching-first'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('matching-delete-one')));
      await tester.pumpAndSettle();
      await confirm(tester, 'Cancel');
      expect(calls, 0);
      expect(saved, [first]);
      expect(
        find.byKey(const ValueKey('matching-delete-selected-first')),
        findsOneWidget,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed authoritative removal preserves selection and is retryable',
    (tester) async {
      final first = await savedPerson('one', 'Saran', '2002-07-29');
      addTearDown(first.session.dispose);
      final saved = [first];
      var calls = 0;
      await openMatching(
        tester,
        saved: saved,
        remove: (row, _) async {
          calls++;
          if (calls == 1) throw StateError('Server deletion was not confirmed');
          saved.remove(row);
        },
      );
      await choose(tester, true, 'one');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final deletion = find.byKey(
        const ValueKey('matching-delete-selected-first'),
      );
      await tester.ensureVisible(deletion);
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      await confirm(tester, 'Delete person');
      expect(
        find.text('Could not delete the saved person. Please retry.'),
        findsWidgets,
      );
      await confirm(tester, 'OK');
      expect(saved, [first]);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      await confirm(tester, 'Delete person');
      expect(calls, 2);
      expect(saved, isEmpty);
      expect(deletion, findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account switch during confirmation cannot delete a saved person',
    (tester) async {
      final first = await savedPerson('one', 'Saran', '2002-07-29');
      addTearDown(first.session.dispose);
      var calls = 0;
      await openMatching(
        tester,
        saved: [first],
        remove: (_, _) async => calls++,
      );
      await choose(tester, true, 'one');
      final deletion = find.byKey(
        const ValueKey('matching-delete-selected-first'),
      );
      await tester.ensureVisible(deletion);
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      accountStorage.account = 'other-account';
      await confirm(tester, 'Delete person');
      expect(calls, 0);
      expect(deletion, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'stale loaded account cannot delete and reloads without selected people',
    (tester) async {
      final first = await savedPerson('one', 'Account A Person', '2002-07-29');
      final other = await savedPerson(
        'other',
        'Account B Person',
        '2001-09-16',
      );
      addTearDown(first.session.dispose);
      addTearDown(other.session.dispose);
      var calls = 0;
      await openMatching(
        tester,
        saved: [first],
        load: () async => accountStorage.account == 'matching-delete-account'
            ? [first]
            : [other],
        remove: (_, _) async => calls++,
      );
      await choose(tester, true, 'one');
      final deletion = find.byKey(
        const ValueKey('matching-delete-selected-first'),
      );
      await tester.ensureVisible(deletion);
      await tester.pumpAndSettle();
      accountStorage.account = 'other-account';
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(deletion, findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      final card = find.byKey(const ValueKey('matching-first'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matching-saved-one')), findsNothing);
      expect(
        find.byKey(const ValueKey('matching-saved-other')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending answer prevents deletion and a pending deletion prevents a match',
    (tester) async {
      final first = await savedPerson('one', 'Saran', '2002-07-29');
      final second = await savedPerson('two', 'Shakthi', '2001-09-16');
      addTearDown(first.session.dispose);
      addTearDown(second.session.dispose);
      final saved = [first, second];
      final completion = Completer<void>();
      var calls = 0;
      await openMatching(
        tester,
        saved: saved,
        remove: (row, _) async {
          calls++;
          await completion.future;
          saved.remove(row);
        },
      );
      await choose(tester, true, 'one');
      await choose(tester, false, 'two');
      first.session.answering = true;
      final deletion = find.byKey(
        const ValueKey('matching-delete-selected-first'),
      );
      await tester.ensureVisible(deletion);
      await tester.pumpAndSettle();
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Please wait for this person’s current request to finish before deleting.',
        ),
        findsWidgets,
      );
      expect(calls, 0);
      await confirm(tester, 'OK');
      first.session.answering = false;
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      await confirm(tester, 'Delete person');
      expect(calls, 1);
      await tester.ensureVisible(find.text('See our match'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See our match'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      completion.complete();
      await tester.pumpAndSettle();
      expect(deletion, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'legacy local person removal asks first and saves only that account',
    (tester) async {
      final person = {
        'nickname': 'Local Person',
        'datetime': '2000-01-01T05:00:00+05:30',
        'latitude': 11,
        'longitude': 77,
        'exactTime': true,
        'birthplaceLabel': 'Erode',
      };
      final ownKey = accountStorage.key('jyotara.matching.people.v1');
      const otherKey = 'jyotara.account.other.jyotara.matching.people.v1';
      FlutterSecureStorage.setMockInitialValues({
        ownKey: jsonEncode([person]),
        otherKey: jsonEncode([person]),
      });
      await openMatching(
        tester,
        saved: [],
        remove: (_, _) async => fail('Local person must not remove a chart'),
      );
      final card = find.byKey(const ValueKey('matching-first'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Local Person'),
          matching: find.text('Local Person'),
        ),
      );
      await tester.pumpAndSettle();
      final deletion = find.byKey(
        const ValueKey('matching-delete-selected-first'),
      );
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      await confirm(tester, 'Cancel');
      expect(jsonDecode((await KundliLibrary.storage.read(key: ownKey))!), [
        person,
      ]);
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      await confirm(tester, 'Delete person');
      expect(
        jsonDecode((await KundliLibrary.storage.read(key: ownKey))!),
        isEmpty,
      );
      expect(jsonDecode((await KundliLibrary.storage.read(key: otherKey))!), [
        person,
      ]);
      expect(deletion, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
