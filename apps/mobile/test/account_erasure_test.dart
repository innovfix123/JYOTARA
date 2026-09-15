import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/account_storage.dart';

void main() {
  test('erasure removes owned namespace and legacy copies, preserving other accounts', () async {
    final owner = 'a' * 32, other = 'b' * 32, chart = 'c' * 32;
    final records = <String, String>{
      'jyotara.legacy-owner.v1': owner,
      'nirayana.private-profile.v1': 'legacy',
      'jyotara.kundli.$chart': 'legacy-chart',
      'jyotara.account.$owner.nirayana.private-profile.v1': 'owned',
      'jyotara.account.$other.nirayana.private-profile.v1': 'other',
      'jyotara.phone-access.v1': 'auth',
    };
    final storage = AccountStorage(
      readAll: () async => Map.of(records),
      delete: (key) async {
        records.remove(key);
      },
    );
    await storage.erase(owner);
    expect(
      records.keys,
      unorderedEquals([
        'jyotara.legacy-owner.v1',
        'jyotara.account.$other.nirayana.private-profile.v1',
        'jyotara.phone-access.v1',
      ]),
    );
    await storage.erase(owner); // Safe to retry after partial local cleanup.
  });
  test('erasure cannot select an arbitrary namespace', () async {
    final storage = AccountStorage(
      readAll: () async => throw StateError('must not read'),
    );
    await expectLater(storage.erase(''), throwsFormatException);
  });
}
