import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/tester_access.dart';

void main() {
  final code = 'a' * 48;
  test('verified invitation persists and restores without putting code in body', () async {
    String? saved;
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.test/api/tester/check');
      expect(request.headers['X-Jyotara-Tester-Code'], code);
      expect(request.body, '{}');
      return http.Response('{"access":"granted"}', 200);
    });
    TesterAccess access() => TesterAccess(client: client, baseUrl: 'https://example.test',
      read: () async => saved, write: (value) async { saved = value; });
    final first = access();
    await first.verify(code);
    expect(first.authorized, true);
    var networkCalls = 0;
    final restored = TesterAccess(baseUrl: 'https://example.test', read: () async => saved,
      client: MockClient((_) async { networkCalls++; throw Exception('offline'); }));
    await restored.restore();
    expect(restored.code, code);
    expect(networkCalls, 0);
  });
  test('malformed stored invitation does not unlock local access', () async {
    final access = TesterAccess(read: () async => 'invalid');
    await access.restore();
    expect(access.authorized, false);
    expect(access.code, null);
  });
  test('invalid, expired and unsaved invitations never authorize', () async {
    var calls = 0;
    final denied = TesterAccess(baseUrl: 'https://example.test', client: MockClient((_) async {
      calls++;
      return http.Response('{}', 401);
    }), write: (_) async {});
    await denied.verify('incomplete');
    expect(calls, 0);
    await denied.verify(code);
    expect(denied.authorized, false);
    expect(denied.code, null);
    final unsaved = TesterAccess(baseUrl: 'https://example.test', client: MockClient((_) async =>
      http.Response('{"access":"granted"}', 200)), write: (_) async { throw StateError('storage'); });
    await unsaved.verify(code);
    expect(unsaved.authorized, false);
    expect(unsaved.code, null);
  });
  test('invitation cannot be transmitted over HTTP', () async {
    var calls = 0;
    final access = TesterAccess(baseUrl: 'http://example.test', client: MockClient((_) async {
      calls++;
      return http.Response('{"access":"granted"}', 200);
    }), write: (_) async {});
    await access.verify(code);
    expect(calls, 0);
    expect(access.authorized, false);
  });
}
