import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/account_storage.dart';

void main() {
  test('upgrade preserves known account without leaking legacy data to a new login', () async {
    final id = List.filled(32, 'a').join();
    final records = <String, String>{
      'nirayana.private-profile.v1': 'private chart',
      'jyotara.kundli.index.v1': jsonEncode([id]),
      'jyotara.kundli.$id': 'private kundli',
    };
    AccountStorage store() => AccountStorage(
      read: (k) async => records[k],
      write: (k, v) async {
        records[k] = v;
      },
    );
    await store().migrateLegacy('first');
    expect(
      records['jyotara.account.first.nirayana.private-profile.v1'],
      'private chart',
    );
    expect(
      records['jyotara.account.first.jyotara.kundli.$id'],
      'private kundli',
    );
    await store().migrateLegacy('second');
    expect(
      records['jyotara.account.second.nirayana.private-profile.v1'],
      isNull,
    );
    expect(records['nirayana.private-profile.v1'], 'private chart');
  });
  test('unowned legacy records never transfer to a new account', () async {
    final records = <String, String>{'nirayana.private-profile.v1': 'legacy'};
    AccountStorage store() => AccountStorage(
      read: (k) async => records[k],
      write: (k, v) async {
        records[k] = v;
      },
    );
    await store().migrateLegacy(null);
    await store().migrateLegacy('new');
    expect(records['jyotara.account.new.nirayana.private-profile.v1'], isNull);
    expect(records['nirayana.private-profile.v1'], 'legacy');
  });
}
