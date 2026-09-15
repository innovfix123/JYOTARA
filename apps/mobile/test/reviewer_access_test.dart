import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  test('expired pending review deletion recovers without opening or recreating account', () async {
    String? saved;
    var erased = false;
    final access = PhoneAccess(
      testerCode: () => null,
      read: () async => jsonEncode({
        'accountId': 'demo',
        'token': 'a' * 64,
        'expiresAt': 1,
        'deletionPending': true,
        'reviewAccount': true,
      }),
      write: (v) async {
        saved = v;
      },
      eraseLocalAccount: (id) async {
        expect(id, 'demo');
        erased = true;
      },
      client: MockClient((r) async {
        expect(r.url.path, '/api/auth/reviewer-delete');
        return http.Response('{"deleted":true}', 200);
      }),
    );
    await access.restore();
    expect(access.canVerifyReviewDeletion, true);
    await access.reviewerLogin('jyotara-review', 'synthetic-password');
    expect(erased, true);
    expect(access.authorized, false);
    expect(access.deletionPending, false);
    expect(saved, '{}');
  });
  test(
    'review login isolates storage and never persists password or old phone',
    () async {
      var prepared = false;
      String? saved;
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async =>
            jsonEncode({'accountId': 'old', 'mobile': '9000000000'}),
        prepareAccount: (id) async {
          expect(id, 'demo');
          prepared = true;
        },
        write: (value) async {
          expect(prepared, true);
          saved = value;
        },
        client: MockClient((r) async {
          expect(r.url.path, '/api/auth/reviewer');
          return http.Response(
            jsonEncode({
              'token': 'a' * 64,
              'accountId': 'demo',
              'expiresAt': DateTime.now()
                  .add(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            }),
            200,
          );
        }),
      );
      await access.restore();
      await access.reviewerLogin('jyotara-review', 'synthetic-password');
      expect(access.authorized, true);
      expect(access.mobile, isNull);
      expect(saved, isNot(contains('synthetic-password')));
      expect(saved, isNot(contains('9000000000')));
    },
  );
  test(
    'failed review sign-in leaves original account unauthenticated',
    () async {
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async => null,
        write: (_) async => fail('Must not persist failed login'),
        client: MockClient(
          (_) async =>
              http.Response('{"error":"Invalid review credentials."}', 401),
        ),
      );
      await access.reviewerLogin('jyotara-review', 'bad');
      expect(access.authorized, false);
      expect(access.error, 'Invalid review credentials.');
    },
  );
}
