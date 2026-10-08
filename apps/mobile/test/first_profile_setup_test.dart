import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/first_profile_setup.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';

class SavedProfile extends ProfileSession {
  @override
  Map<String, dynamic>? get facts => {'saved': true};
}

void main() {
  testWidgets('new verified user sees gender and birth setup before home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstProfileSetup(
          session: ProfileSession(),
          child: const Text('Home content'),
        ),
      ),
    );
    expect(find.text('Gender *', findRichText: true), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Home content'), findsNothing);
    final complete = tester
        .widget<BirthForm>(find.byType(BirthForm))
        .onCompleted!;
    complete();
    await tester.pump();
    expect(
      find.text('Home content'),
      findsNothing,
      reason: 'Incomplete calculation must not bypass setup',
    );
    await tester.tap(find.byKey(const ValueKey('gender-male')));
    await tester.pump();
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Home content'), findsNothing);
  });
  testWidgets('returning user keeps the saved profile and enters the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstProfileSetup(
          session: SavedProfile(),
          child: const Text('Home content'),
        ),
      ),
    );
    expect(find.text('Home content'), findsOneWidget);
    expect(find.byType(BirthForm), findsNothing);
  });
  testWidgets(
    'failed storage can retry or return Home without deleting the record',
    (tester) async {
      String? disk = 'invalid json';
      var writes = 0;
      final session = ProfileSession(
        vault: LocalProfileVault(
          read: () async => disk,
          write: (value) async {
            writes++;
            disk = value;
          },
        ),
      );
      await session.restore();
      await tester.pumpWidget(
        MaterialApp(
          home: FirstProfileSetup(
            session: session,
            child: const Text('Home content'),
          ),
        ),
      );
      expect(find.text('Saved profiles'), findsOneWidget);
      await tester.tap(find.text('Retry opening saved profiles'));
      await tester.pumpAndSettle();
      expect(find.text('Saved profiles'), findsOneWidget);
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();
      expect(find.text('Home content'), findsOneWidget);
      expect(writes, 0);
      expect(disk, 'invalid json');
    },
  );
}
