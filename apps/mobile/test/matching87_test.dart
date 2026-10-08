import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/main.dart' show accountStorage;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    accountStorage.account = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  });
  tearDown(() => accountStorage.account = null);
  test(
    'saved matches retain factors, avoid duplicates and isolate accounts',
    () async {
      final result = <String, dynamic>{
        'boyName': 'A',
        'girlName': 'B',
        'score': 24,
        'maximum': 36,
        'factors': [
          {'name': 'Tara', 'score': 3, 'maximum': 3},
        ],
        'wallet': {'coins': 20},
      };
      await SavedMatches.save(result);
      await SavedMatches.save(result);
      final saved = await SavedMatches.load();
      expect(saved.length, 1);
      expect(saved.first.containsKey('wallet'), false);
      expect(saved.first['factors'], result['factors']);
      accountStorage.account = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      expect(await SavedMatches.load(), isEmpty);
      accountStorage.account = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      await SavedMatches.remove(saved.first);
      expect(await SavedMatches.load(), isEmpty);
    },
  );
  testWidgets(
    'reopening a saved match is local and does not show a new debit',
    (tester) async {
      await SavedMatches.save({
        'boyName': 'A',
        'girlName': 'B',
        'score': 18,
        'maximum': 36,
        'factors': [],
        'wallet': {'coins': 20},
      });
      await tester.pumpWidget(const MaterialApp(home: SavedMatchesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A · B'));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('20 coins used'), findsNothing);
      expect(find.text('Saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced-motion matching remains readable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: MatchingAnimation(first: 'One', second: 'Two'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Comparing your two charts…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
