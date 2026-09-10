import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  test(
    'send never authorizes; verified token is securely saved and restored',
    () async {
      String? saved;
      final token = List.filled(64, 'a').join();
      final client = MockClient((request) async {
        expect(request.headers['X-Jyotara-Tester-Code'], 'tester');
        if (request.url.path.endsWith('/send')) {
          return http.Response(
            jsonEncode({'challengeId': List.filled(48, 'b').join()}),
            200,
          );
        }
        expect(jsonDecode(request.body)['otp'], '123456');
        return http.Response(
          jsonEncode({
            'token': token,
            'accountId': 'account',
            'expiresAt': DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
          }),
          200,
        );
      });
      final access = PhoneAccess(
        testerCode: () => 'tester',
        client: client,
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      await access.send('9000000000');
      expect(access.authorized, false);
      expect(access.codeSent, true);
      await access.verify('123456');
      expect(access.authorized, true);
      expect(access.token, token);
      expect(saved, isNot(contains('123456')));
      final restored = PhoneAccess(
        testerCode: () => 'tester',
        read: () async => saved,
      );
      await restored.restore();
      expect(restored.token, token);
    },
  );
  test('wrong OTP does not write credentials', () async {
    var writes = 0;
    final access = PhoneAccess(
      testerCode: () => 'tester',
      write: (_) async {
        writes++;
      },
      client: MockClient(
        (r) async => r.url.path.endsWith('/send')
            ? http.Response(
                jsonEncode({'challengeId': List.filled(48, 'b').join()}),
                200,
              )
            : http.Response('{"error":"Invalid or expired code."}', 400),
      ),
    );
    await access.send('9000000000');
    await access.verify('123456');
    expect(access.authorized, false);
    expect(writes, 0);
    expect(access.error, 'Invalid or expired code.');
  });
  test('another phone account cannot replace the saved account', () async {
    var writes = 0, logout = false;
    final access = PhoneAccess(
      testerCode: () => 'tester',
      read: () async => jsonEncode({'accountId': 'original'}),
      write: (_) async {
        writes++;
      },
      client: MockClient((r) async {
        if (r.url.path.endsWith('/send')) {
          return http.Response(
            jsonEncode({'challengeId': List.filled(48, 'b').join()}),
            200,
          );
        }
        if (r.url.path.endsWith('/logout')) {
          logout = true;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'token': List.filled(64, 'a').join(),
            'accountId': 'other',
            'expiresAt': DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
          }),
          200,
        );
      }),
    );
    await access.restore();
    await access.send('9000000000');
    await access.verify('123456');
    expect(access.authorized, false);
    expect(writes, 0);
    expect(logout, true);
  });
}
