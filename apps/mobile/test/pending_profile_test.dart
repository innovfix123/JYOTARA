import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/jyotara_api.dart';

Future<void> calculate(ProfileSession session) => session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
void main() {
  test('deleting during recovery-record save prevents transport and removes the record', () async {
    final writing = Completer<void>();
    final started = Completer<void>();
    String? disk;
    var calls = 0;
    final session = ProfileSession(
      vault: LocalProfileVault(write: (value) async {
        if (value != null) { started.complete(); await writing.future; }
        disk = value;
      }),
      api: JyotaraApiClient(client: MockClient((_) async { calls++; return http.Response('{}', 500); })),
    );
    final request = calculate(session);
    await started.future;
    final deletion = session.clear();
    writing.complete();
    await request;
    await deletion;
    expect(calls, 0);
    expect(disk, isNull);
    expect(session.facts, isNull);
  });
  test('first request identity is durable before send and retained after lost response/restart', () async {
    String? disk;
    final cookies = <String?>[];
    final vault = LocalProfileVault(read: () async => disk, write: (value) async => disk = value);
    JyotaraApiClient api() => JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      cookies.add(request.headers['cookie']);
      final saved = jsonDecode(disk!);
      expect(saved['kind'], 'pending-profile');
      expect(saved['session'], request.headers['cookie']);
      expect(saved.containsKey('datetime'), false);
      throw http.ClientException('Synthetic lost response');
    }));
    final first = ProfileSession(api: api(), vault: vault);
    await expectLater(calculate(first), throwsA(isA<JyotaraApiException>()));
    expect(first.profileRequestUnconfirmed, true);
    final second = ProfileSession(api: api(), vault: vault);
    await second.restore();
    expect(cookies.length, 1, reason: 'Restore must never resend automatically');
    expect(second.facts, isNull);
    expect(second.profileRequestUnconfirmed, true);
    await expectLater(calculate(second), throwsA(isA<JyotaraApiException>()));
    expect(cookies[0], isNotNull);
    expect(cookies[1], cookies[0]);
    await second.clear();
    expect(disk, isNull);
    expect(second.profileRequestUnconfirmed, false);
  });
  test('recovery record write failure prevents first provider request', () async {
    var calls = 0;
    final session = ProfileSession(
      vault: LocalProfileVault(write: (_) async => throw StateError('disk unavailable')),
      api: JyotaraApiClient(client: MockClient((_) async { calls++; return http.Response('{}', 500); })),
    );
    await expectLater(calculate(session), throwsA(isA<JyotaraApiException>()));
    expect(calls, 0);
    expect(session.calculating, false);
  });
}
