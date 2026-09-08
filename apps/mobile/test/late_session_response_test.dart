import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  for (final replacement in <String?>[null, 'nirayana_pilot_session=new-session', 'nirayana_pilot_session=original']) {
    test('late response cannot restore a cleared or replaced session: $replacement', () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final api = JyotaraApiClient(client: MockClient((_) async { calls++; return response.future; }));
      api.restoreSession('nirayana_pilot_session=original');
      final request = api.searchLocations('Erode');
      final rejected = expectLater(request, throwsA(isA<JyotaraApiException>().having((e) => e.deliveryUncertain, 'uncertain delivery', true)));
      api.restoreSession(replacement);
      response.complete(http.Response('{"data":[]}', 200, headers: {'set-cookie':'nirayana_pilot_session=old-response; HttpOnly'}));
      await rejected;
      expect(api.sessionForStorage, replacement);
      expect(calls, 1);
      api.close();
    });
  }
  test('malformed returned session cannot poison saved identity', () async {
    final api = JyotaraApiClient(client: MockClient((_) async => http.Response('{"data":[]}', 200, headers: {'set-cookie':'nirayana_pilot_session=bad%20session; HttpOnly'})));
    api.restoreSession('nirayana_pilot_session=original');
    await expectLater(api.searchLocations('Erode'), throwsA(isA<JyotaraApiException>()));
    expect(api.sessionForStorage, 'nirayana_pilot_session=original');
    api.close();
  });
  test('unchanged session may accept its own valid response', () async {
    final api = JyotaraApiClient(client: MockClient((_) async => http.Response('{"data":[]}', 200, headers: {'set-cookie':'nirayana_pilot_session=server-session; HttpOnly'})));
    await api.searchLocations('Erode');
    expect(api.sessionForStorage, 'nirayana_pilot_session=server-session');
    api.close();
  });
}
