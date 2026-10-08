import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  test(
    'lost send response survives restart and retry preserves request identity',
    () async {
      String? saved;
      var now = DateTime(2026, 10, 7, 12);
      final ids = <String>[];
      final client = MockClient((r) async {
        ids.add(jsonDecode(r.body)['requestId']);
        if (ids.length == 1) throw http.ClientException('lost response');
        return http.Response(
          jsonEncode({
            'challengeId': 'b' * 48,
            'expiresIn': 239,
            'retryAfterSeconds': 0,
          }),
          200,
        );
      });
      PhoneAccess create() => PhoneAccess(
        testerCode: () => 'test',
        client: client,
        now: () => now,
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      final first = create();
      await first.send('9000000000');
      now = now.add(const Duration(seconds: 61));
      final second = create();
      await second.restore();
      await second.send('9000000000');
      expect(ids[0], matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(ids[1], ids[0]);
      expect(second.codeSecondsRemaining, 239);
      await second.send('9000000000');
      expect(
        ids[2],
        isNot(ids[1]),
        reason: 'Intentional resend is a new request',
      );
    },
  );

  test(
    'real SMS build discards saved demo authentication and requests SMS',
    () async {
      String? saved = jsonEncode({
        'officeDemoChallenge': true,
        'accountId': 'office_demo_example',
        'token': 'a' * 64,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      });
      final access = PhoneAccess(
        requireRealSms: true,
        testerCode: () => 'test',
        read: () async => saved,
        write: (value) async {
          saved = value;
        },
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['officeDemo'], false);
          return http.Response(jsonEncode({'challengeId': 'b' * 48}), 200);
        }),
      );
      await access.restore();
      expect(access.authorized, false);
      expect(access.accountId, null);
      expect(saved, '{}');
      await access.send('9000000000');
      expect(access.codeSent, true);
      expect(access.notice, contains('SMS requested'));
    },
  );

  test(
    'demo challenge survives restart and remains separate from real login',
    () async {
      String? saved;
      final client = MockClient((r) async {
        final body = jsonDecode(r.body);
        if (r.url.path.endsWith('/send')) {
          return http.Response(
            jsonEncode({
              'challengeId': List.filled(48, 'b').join(),
              'officeDemo': true,
            }),
            200,
          );
        }
        expect(body['officeDemo'], true);
        return http.Response(
          jsonEncode({
            'token': List.filled(64, 'a').join(),
            'accountId': 'office_demo_example',
            'expiresAt': DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
          }),
          200,
        );
      });
      PhoneAccess create() => PhoneAccess(
        testerCode: () => 'test',
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
        client: client,
      );
      final first = create();
      await first.send('9000000000');
      final restored = create();
      await restored.restore();
      expect(restored.notice, 'Enter your office review OTP.');
      await restored.verify('011011');
      expect(restored.authorized, true);
      expect(restored.officeDemo, true);
      final loggedIn = create();
      await loggedIn.restore();
      expect(loggedIn.officeDemo, true);
    },
  );

  test(
    'new account storage is prepared before credentials authorize access',
    () async {
      var prepared = false;
      String? stored;
      final access = PhoneAccess(
        testerCode: () => 'test',
        read: () async => jsonEncode({'accountId': 'old'}),
        prepareAccount: (id) async {
          expect(id, 'new');
          prepared = true;
        },
        write: (value) async {
          if (jsonDecode(value)['token'] != null) expect(prepared, true);
          stored = value;
        },
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/send')
                  ? {'challengeId': List.filled(48, 'b').join()}
                  : {
                      'token': List.filled(64, 'a').join(),
                      'accountId': 'new',
                      'expiresAt': DateTime.now()
                          .add(const Duration(days: 1))
                          .millisecondsSinceEpoch,
                    },
            ),
            200,
          ),
        ),
      );
      await access.restore();
      await access.send('9000000000');
      await access.verify('123456');
      expect(access.authorized, true);
      expect(access.accountId, 'new');
      expect(jsonDecode(stored!)['mobile'], '9000000000');
    },
  );

  test(
    'pending OTP survives restart without sending again or resetting expiry',
    () async {
      String? saved;
      var sends = 0;
      var now = DateTime(2026, 9, 10, 12);
      final client = MockClient((r) async {
        sends++;
        return http.Response(
          jsonEncode({'challengeId': List.filled(48, 'b').join()}),
          200,
        );
      });
      final first = PhoneAccess(
        testerCode: () => 'tester',
        client: client,
        now: () => now,
        write: (v) async {
          saved = v;
        },
      );
      await first.send('9000000000');
      expect(sends, 1);
      now = now.add(const Duration(seconds: 20));
      final second = PhoneAccess(
        testerCode: () => 'tester',
        client: client,
        now: () => now,
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      await second.restore();
      expect(second.codeSent, true);
      expect(second.mobile, '9000000000');
      expect(second.codeSecondsRemaining, 280);
      expect(sends, 1);
      await second.send('9000000000');
      expect(sends, 1, reason: 'Restart must not bypass the cooldown');
      now = now.add(const Duration(minutes: 5));
      final third = PhoneAccess(
        testerCode: () => 'tester',
        client: client,
        now: () => now,
        read: () async => saved,
      );
      await third.restore();
      expect(third.codeSent, true);
      expect(third.codeExpired, true);
      await third.verify('123456');
      expect(sends, 1, reason: 'Expired code must not be submitted');
    },
  );
  test('hourly limit countdown survives restart', () async {
    String? saved;
    final now = DateTime(2026, 9, 10, 12);
    final access = PhoneAccess(
      testerCode: () => 'tester',
      now: () => now,
      write: (v) async {
        saved = v;
      },
      client: MockClient(
        (_) async => http.Response(
          '{"error":"Wait 15 minutes","retryAfterSeconds":900}',
          429,
        ),
      ),
    );
    await access.send('9000000000');
    final restored = PhoneAccess(
      testerCode: () => 'tester',
      now: () => now,
      read: () async => saved,
    );
    await restored.restore();
    expect(restored.resendAt, now.add(const Duration(minutes: 15)));
    expect(restored.authorized, false);
  });

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
    expect(
      writes,
      2,
      reason: 'Retry identity and challenge are saved, never a login token',
    );
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
    expect(
      writes,
      2,
      reason: 'Retry identity and challenge are saved, never a login token',
    );
    expect(logout, true);
  });
}
