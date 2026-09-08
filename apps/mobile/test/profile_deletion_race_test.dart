import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  test('repeated deletion coalesces and blocks profile creation until settled', () async {
    final deletion = Completer<void>();
    var deletes = 0;
    var requests = 0;
    final session = ProfileSession(
      vault: LocalProfileVault(write: (_) async {
        deletes++;
        await deletion.future;
      }),
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          requests++;
          return chartReply('new');
        }),
      ),
    );
    final first = session.clear();
    final second = session.clear();
    expect(identical(first, second), true);
    expect(session.deleting, true);
    await expectLater(session.calculate(
      dateTime: '2002-07-29T05:00:00+05:30',
      latitude: 11, longitude: 77, exactTime: true,
    ), throwsA(isA<JyotaraApiException>()));
    expect(requests, 0);
    expect(deletes, 1);
    deletion.complete();
    await first;
    expect(session.deleting, false);
    expect(session.storageError, null);
  });

  test('failed deletion unlocks retry; stale save cannot clear its error', () async {
    final writing = Completer<void>();
    var deletes = 0;
    final session = ProfileSession(
      vault: LocalProfileVault(write: (value) async {
        if (value != null) {
          // The preflight identity must finish before transport; this test
          // delays only the later completed-profile save being deleted.
          if (jsonDecode(value)['kind'] != 'pending-profile') await writing.future;
        } else if (++deletes == 1) {
          throw StateError('test-only device failure');
        }
      }),
      api: JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => chartReply('original')),
      ),
    );
    await session.calculate(
      dateTime: '2002-07-29T05:00:00+05:30',
      latitude: 11, longitude: 77, exactTime: true,
    );
    session.storageError = 'Existing save failure';
    final deleting = session.clear();
    final failed = expectLater(deleting, throwsStateError);
    writing.complete();
    await session.flushStorage();
    await failed;
    expect(session.facts, null);
    expect(session.deleting, false);
    expect(session.storageError, contains('Device deletion failed'));
    await session.clear();
    expect(deletes, 2);
    expect(session.storageError, null);
  });
}
