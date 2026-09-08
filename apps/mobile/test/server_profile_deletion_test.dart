import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'profile_replacement_test.dart' show chartReply;

void main() {
  test('server erasure failure retains restart capability; success clears device and identity', () async {
    String? disk;
    var deletionCalls = 0;
    var fail = true;
    final vault = LocalProfileVault(read: () async => disk, write: (value) async => disk = value);
    JyotaraApiClient client() => JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) return chartReply('saved');
      expect(request.url.path, '/api/profile/delete');
      expect(request.headers['cookie'], 'nirayana_pilot_session=saved');
      expect(jsonDecode(request.body), {'chartTicket': 'ticket-saved', 'profileId': 'saved'});
      deletionCalls++;
      if (fail) throw http.ClientException('synthetic offline');
      return http.Response(jsonEncode({'deleted': true, 'scope': 'anonymous_chart_session'}), 200);
    }));
    final original = ProfileSession(api: client(), vault: vault);
    await original.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await original.flushStorage();
    final before = disk;
    await expectLater(original.clear(includeServer: true), throwsA(isA<JyotaraApiException>()));
    expect(disk, isNot(before));
    expect(jsonDecode(disk!)['deletionRequested'], true);
    expect(original.facts, isNotNull);
    expect(original.storageError, contains('not confirmed'));
    await expectLater(original.ask(category: 'Career', question: 'Question?', responseStyle: 'english'), throwsA(isA<JyotaraApiException>()));
    final restoredApi = client();
    final restored = ProfileSession(api: restoredApi, vault: vault);
    await restored.restore();
    expect(restored.canDeleteServer, true);
    expect(restored.storageError, contains('Retry deletion'));
    await expectLater(restored.ask(category: 'Career', question: 'A new question?', responseStyle: 'english'), throwsA(isA<JyotaraApiException>()));
    expect(deletionCalls, 1, reason: 'restore must not automatically retry deletion or allow chat transport');
    fail = false;
    await restored.clear(includeServer: true);
    expect(deletionCalls, 2);
    expect(disk, null);
    expect(restored.facts, null);
    expect(restoredApi.sessionForStorage, null);
    expect(restored.storageError, null);
  });

  test('repeated server deletion coalesces; local erase failure retains retry capability', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    var deviceFails = true;
    final session = ProfileSession(api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) return chartReply('saved');
      calls++;
      return response.future;
    })), vault: LocalProfileVault(write: (value) async {
      if (value == null && deviceFails) throw StateError('synthetic disk failure');
    }));
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await session.flushStorage();
    final first = session.clear(includeServer: true);
    expect(identical(first, session.clear(includeServer: true)), true);
    final failed = expectLater(first, throwsStateError);
    response.complete(http.Response(jsonEncode({'deleted': true, 'scope': 'anonymous_chart_session'}), 200));
    await failed;
    expect(calls, 1);
    expect(session.canDeleteServer, true);
    expect(session.storageError, contains('Device deletion failed'));
    deviceFails = false;
    await session.clear(includeServer: true);
    expect(calls, 2);
    expect(session.canDeleteServer, false);
    expect(session.storageError, null);
  });

  test('a bare HTTP success is not deletion confirmation', () async {
    final api = JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((_) async => http.Response('{}', 200)));
    api.restoreSession('nirayana_pilot_session=saved');
    await expectLater(api.deleteChartSession(chartTicket: 'synthetic', profileId: 'saved'), throwsA(isA<JyotaraApiException>()));
  });

  test('failed deletion checkpoint prevents server request and supports explicit retry', () async {
    String? disk;
    var failCheckpoint = true;
    var calls = 0;
    final session = ProfileSession(vault: LocalProfileVault(read: () async => disk, write: (value) async {
      if (value != null && jsonDecode(value)['deletionRequested'] == true && failCheckpoint) {
        throw StateError('synthetic checkpoint failure');
      }
      disk = value;
    }), api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.url.path.endsWith('kundli')) return chartReply('saved');
      calls++;
      return http.Response(jsonEncode({'deleted': true, 'scope': 'anonymous_chart_session'}), 200);
    })));
    await session.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await session.flushStorage();
    final saved = disk;
    await expectLater(session.clear(includeServer: true), throwsA(isA<JyotaraApiException>()));
    expect(calls, 0);
    expect(disk, saved);
    expect(session.canDeleteServer, true);
    failCheckpoint = false;
    await session.clear(includeServer: true);
    expect(calls, 1);
    expect(disk, null);
  });
}
