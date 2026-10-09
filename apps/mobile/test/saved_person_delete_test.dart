import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/chat_profile_picker.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/main.dart' show accountStorage, guides, profileSession;
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    accountStorage.account = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  });
  tearDown(() => accountStorage.account = null);

  SavedKundli person(String id, String name) {
    final session = ProfileSession()..nickname = name;
    session
        .conversation('Meera')
        .messages
        .add(ChatMessage(fromUser: true, text: '$name saved question'));
    addTearDown(session.dispose);
    return SavedKundli(id, session);
  }

  Widget screen(
    bool ask,
    List<SavedKundli> rows,
    Future<void> Function(SavedKundli, List<SavedKundli>) remove,
  ) => ask
      ? ChatProfilePicker(
          guide: guides.first,
          loadProfiles: () async => [
            SavedKundli('personal', profileSession),
            ...rows,
          ],
          removeProfile: remove,
        )
      : KundliLibraryScreen(
          includeOwnProfile: true,
          loadProfiles: () async => rows,
          removeProfile: remove,
        );

  Finder deleteButton(bool ask, String id) =>
      find.byKey(ValueKey('${ask ? 'chat' : 'library'}-delete-profile-$id'));
  Finder profileRow(bool ask, String id) =>
      find.byKey(ValueKey('${ask ? 'chat' : 'library'}-profile-$id'));

  Future<void> revealDelete(WidgetTester tester, bool ask, String id) async {
    await tester.scrollUntilVisible(
      deleteButton(ask, id),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(deleteButton(ask, id));
    await tester.pumpAndSettle();
  }

  for (final ask in [false, true]) {
    for (final language in ['en', 'ta']) {
      testWidgets(
        '${ask ? 'Ask' : 'library'} $language deletes one named person, supports cancel and failure retry at 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final originalNickname = profileSession.nickname;
          profileSession.nickname = 'Primary profile';
          addTearDown(() => profileSession.nickname = originalNickname);
          final one = person('one', language == 'ta' ? 'அனிதா' : 'Anitha');
          final two = person('two', 'Kumar');
          final rows = [one, two];
          var calls = 0;
          var fail = false;
          final ui = UiLanguagePreferences(write: (_) async {});
          await ui.set(language);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => UiLanguageScope(
                preferences: ui,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: screen(ask, rows, (row, library) async {
                calls++;
                expect(library.any((row) => row.id == 'personal'), isFalse);
                if (fail) throw Exception('Fixture deletion failure');
                await row.session.clear();
                rows.remove(row);
              }),
            ),
          );
          await tester.pumpAndSettle();
          expect(deleteButton(ask, 'personal'), findsNothing);
          await revealDelete(tester, ask, 'one');
          await tester.tap(deleteButton(ask, 'one'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              language == 'ta' ? 'அனிதா விவரங்களை நீக்கவா?' : 'Delete Anitha?',
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const Key('cancel-saved-profile-delete')),
          );
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(rows, [one, two]);
          await tester.tap(deleteButton(ask, 'one'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('confirm-saved-profile-delete')),
          );
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(profileRow(ask, 'one'), findsNothing);
          expect(rows, [two]);
          expect(
            two.session.conversation('Meera').messages.single.text,
            'Kumar saved question',
          );
          expect(profileSession.nickname, 'Primary profile');

          fail = true;
          await revealDelete(tester, ask, 'two');
          await tester.tap(deleteButton(ask, 'two'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('confirm-saved-profile-delete')),
          );
          await tester.pumpAndSettle();
          expect(rows, [two]);
          expect(
            find.text(
              language == 'ta'
                  ? 'இந்த நபரின் விவரங்களை நீக்க முடியவில்லை. மீண்டும் முயலுங்கள்.'
                  : 'This person could not be deleted. Please retry.',
            ),
            findsOneWidget,
          );
          expect(
            two.session.conversation('Meera').messages.single.text,
            'Kumar saved question',
          );
          fail = false;
          await revealDelete(tester, ask, 'two');
          await tester.tap(deleteButton(ask, 'two'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('confirm-saved-profile-delete')),
          );
          await tester.pumpAndSettle();
          expect(calls, 3);
          expect(rows, isEmpty);
          expect(profileSession.nickname, 'Primary profile');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      '${ask ? 'Ask' : 'library'} refuses old-account confirmation and clears stale people',
      (tester) async {
        final row = person('old-owner', 'Old account person');
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(home: screen(ask, [row], (_, _) async => calls++)),
        );
        await tester.pumpAndSettle();
        await revealDelete(tester, ask, row.id);
        await tester.tap(deleteButton(ask, row.id));
        await tester.pumpAndSettle();
        accountStorage.account = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        await tester.tap(find.byKey(const Key('confirm-saved-profile-delete')));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(profileRow(ask, row.id), findsNothing);
        expect(
          find.text('Account changed. Reopen saved profiles.'),
          findsOneWidget,
        );
        expect(
          row.session.conversation('Meera').messages.single.text,
          'Old account person saved question',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '${ask ? 'Ask' : 'library'} keeps active question and receipt state while request is running',
      (tester) async {
        final row = person('busy', 'Busy person');
        row.session.answering = true;
        final chat = row.session.conversation('Meera')..pending = true;
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(home: screen(ask, [row], (_, _) async => calls++)),
        );
        await tester.pumpAndSettle();
        await revealDelete(tester, ask, row.id);
        await tester.tap(deleteButton(ask, row.id));
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(
          find.byKey(const Key('confirm-saved-profile-delete')),
          findsNothing,
        );
        expect(
          find.text('Please wait for this person’s current request to finish.'),
          findsOneWidget,
        );
        expect(chat.pending, isTrue);
        expect(row.session.answering, isTrue);
        expect(chat.messages.single.text, 'Busy person saved question');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('saved-person removal changes only that account index and never the primary vault', () async {
    final ownerA = accountStorage.account!;
    final keyA = KundliLibrary.indexKey;
    final one = await KundliLibrary.create([]);
    final two = await KundliLibrary.create([one]);
    await KundliLibrary.storage.write(
      key: accountStorage.key('nirayana.private-profile.v1'),
      value: 'primary A',
    );
    accountStorage.account = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final other = await KundliLibrary.create([]);
    final keyB = KundliLibrary.indexKey;
    await KundliLibrary.storage.write(
      key: accountStorage.key('nirayana.private-profile.v1'),
      value: 'primary B',
    );
    accountStorage.account = ownerA;
    await KundliLibrary.remove(one, [one, two]);
    expect((await KundliLibrary.load()).map((row) => row.id), [two.id]);
    expect(
      await KundliLibrary.storage.read(
        key: accountStorage.key('nirayana.private-profile.v1'),
      ),
      'primary A',
    );
    expect(await KundliLibrary.storage.read(key: keyA), contains(two.id));
    accountStorage.account = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    expect((await KundliLibrary.load()).map((row) => row.id), [other.id]);
    expect(await KundliLibrary.storage.read(key: keyB), contains(other.id));
    expect(
      await KundliLibrary.storage.read(
        key: accountStorage.key('nirayana.private-profile.v1'),
      ),
      'primary B',
    );
    one.session.dispose();
    two.session.dispose();
    other.session.dispose();
  });
}
