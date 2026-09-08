import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test('birthplace search uses configured backend and rejects invalid rows', () async {
    var calls = 0;
    final row = [1272013, 'Erode', 'Tamil Nadu', 'India', 'IN', 'Asia/Kolkata', 11.3428, 77.7274];
    final api = JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      calls++;
      expect(request.url.toString(), 'https://example.test/api/locations');
      expect(jsonDecode(request.body), {'query': 'Erode'});
      return http.Response(jsonEncode({'data': [row, null, [...row.take(6), 999, 77]]}), 200);
    }));
    await expectLater(api.searchLocations('ab'), throwsA(isA<JyotaraApiException>()));
    expect(calls, 0);
    expect(await api.searchLocations(' Erode '), [row]);
    expect(calls, 1);
  });
}
