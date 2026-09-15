import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  test('expired deletion login recovers with same-phone OTP without authorizing app', () async {
    var saved = jsonEncode({
      'token': 'a' * 64,
      'accountId': 'b' * 32,
      'mobile': '9000000000',
      'expiresAt': 1,
      'deletionPending': true,
    });
    final paths = <String>[];
    var erased = false;
    final access = PhoneAccess(
      testerCode: () => null,
      read: () async => saved,
      write: (v) async {
        saved = v;
      },
      eraseLocalAccount: (id) async {
        expect(id, 'b' * 32);
        erased = true;
      },
      client: MockClient((r) async {
        paths.add(r.url.path);
        expect(jsonDecode(r.body)['mobile'], '9000000000');
        if (r.url.path.endsWith('/send')) {
          return http.Response(jsonEncode({'challengeId': 'c' * 48}), 200);
        }
        expect(r.url.path, '/api/auth/verify-deletion');
        return http.Response('{"deleted":true}', 200);
      }),
    );
    await access.restore();
    expect(access.authorized, false);
    await access.send('9111111111', deletionOnly: true);
    expect(paths, isEmpty);
    await access.requestDeletionCode();
    expect(access.deletionCodeSent, true);
    expect(access.authorized, false);
    expect(await access.verifyDeletionCode('123456'), true);
    expect(erased, true);
    expect(access.authorized, false);
    expect(paths, ['/api/auth/send', '/api/auth/verify-deletion']);
    expect(jsonDecode(saved), isEmpty);
  });
  test('acknowledged deletion resumes local cleanup after restart without API calls', () async {
    var saved = jsonEncode({
      'token': 'a' * 64,
      'accountId': 'b' * 32,
      'expiresAt': DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
    });
    var calls = 0;
    final first = PhoneAccess(
      testerCode: () => 'tester',
      read: () async => saved,
      write: (v) async {
        saved = v;
      },
      eraseLocalAccount: (_) async => throw StateError('storage unavailable'),
      client: MockClient((r) async {
        calls++;
        return http.Response('{"deleted":true}', 200);
      }),
    );
    await first.restore();
    expect(await first.deleteAccount(), false);
    expect(first.authorized, false);
    expect(first.deletionPending, true);
    expect(jsonDecode(saved)['serverDeleted'], true);
    await first.signOut();
    await first.send('9000000000');
    expect(calls, 1);
    var erased = false;
    final restored = PhoneAccess(
      testerCode: () => 'tester',
      read: () async => saved,
      write: (v) async {
        saved = v;
      },
      eraseLocalAccount: (id) async {
        expect(id, 'b' * 32);
        erased = true;
      },
      client: MockClient((_) async => throw StateError('must not call server')),
    );
    await restored.restore();
    expect(restored.authorized, false);
    expect(await restored.deleteAccount(), true);
    expect(erased, true);
    expect(restored.accountId, null);
    expect(jsonDecode(saved), isEmpty);
  });
  test(
    'lost server response retains credentials for explicit deletion retry',
    () async {
      var saved = jsonEncode({
        'token': 'a' * 64,
        'accountId': 'b' * 32,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      });
      var calls = 0, erased = false;
      final access = PhoneAccess(
        testerCode: () => 'tester',
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
        eraseLocalAccount: (_) async {
          erased = true;
        },
        client: MockClient((_) async {
          if (++calls == 1) throw http.ClientException('lost');
          return http.Response('{"deleted":true}', 200);
        }),
      );
      await access.restore();
      expect(await access.deleteAccount(), false);
      expect(erased, false);
      expect(jsonDecode(saved)['token'], 'a' * 64);
      expect(await access.deleteAccount(), true);
      expect(erased, true);
      expect(calls, 2);
    },
  );
}
