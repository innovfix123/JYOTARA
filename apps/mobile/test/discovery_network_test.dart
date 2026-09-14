import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/discovery_screens.dart';

void main() {
  test(
    'offline discovery hides transport details and allows a fresh retry',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        if (++calls == 1) {
          throw http.ClientException(
            'Network unreachable, private-host:443',
            request.url,
          );
        }
        return http.Response('{"sections":[]}', 200);
      });
      await expectLater(
        discoveryRequest('/api/horoscope/daily', {}, client: client),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Check your internet') &&
                !e.toString().contains('private-host'),
          ),
        ),
      );
      expect(calls, 1);
      expect(
        await discoveryRequest('/api/horoscope/daily', {}, client: client),
        {'sections': []},
      );
      expect(calls, 2);
    },
  );
  test('invalid gateway content has a readable error', () async {
    final client = MockClient(
      (_) async => http.Response('<html>Bad gateway</html>', 502),
    );
    await expectLater(
      discoveryRequest('/api/horoscope/daily', {}, client: client),
      throwsA(
        predicate(
          (e) =>
              e.toString().contains('could not be loaded') &&
              !e.toString().contains('<html>'),
        ),
      ),
    );
  });
}
