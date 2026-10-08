import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/account_storage.dart';
import 'package:jyotara/services/account_profile_session.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test(
    'same-phone reload restores profile and isolates other accounts',
    () async {
      final disk = <String, String>{};
      final storage = AccountStorage(
        read: (k) async => disk[k],
        write: (k, v) async {
          disk[k] = v;
        },
      );
      JyotaraApiClient api() => JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'sandbox': false,
              'chartTicket': 'TEST',
              'profileId': 'profile-test',
              'result': {
                'data': {
                  'nakshatra_details': {
                    'chandra_rasi': {'name': 'Meena'},
                    'nakshatra': {'name': 'Uttara Bhadrapada'},
                  },
                },
              },
            }),
            200,
            headers: {
              'set-cookie': 'nirayana_pilot_session=session-test; HttpOnly',
            },
          ),
        ),
      );
      ProfileSession create() {
        final key = storage.key('nirayana.private-profile.v1');
        return ProfileSession(
          api: api(),
          vault: LocalProfileVault(
            read: () async => disk[key],
            write: (v) async {
              if (v == null) {
                disk.remove(key);
              } else {
                disk[key] = v;
              }
            },
          ),
        );
      }

      storage.account = 'a' * 32;
      final original = create();
      await original.calculate(
        dateTime: '2002-07-29T17:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
        nickname: 'Test User',
      );
      await original.flushStorage();
      expect(original.facts, isNotNull);
      final restored = await restoreAccountProfile(
        account: 'a' * 32,
        storage: storage,
        current: create(),
        create: create,
      );
      expect(restored.nickname, 'Test User');
      expect(restored.birthTimeKnown, true);
      expect(restored.facts?['rashi'], 'Meena');
      final other = await restoreAccountProfile(
        account: 'b' * 32,
        storage: storage,
        current: restored,
        create: create,
      );
      expect(other.facts, isNull);
      final again = await restoreAccountProfile(
        account: 'a' * 32,
        storage: storage,
        current: other,
        create: create,
      );
      expect(again.nickname, 'Test User');
    },
  );
}
