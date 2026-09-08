import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test(
    'recovery and restart do not relabel a new Bhukti as an old calculation',
    () async {
      String? disk;
      var calls = 0;
      var now = DateTime.utc(2026, 9, 7, 12);
      final original = DateTime.utc(2026, 9, 7, 8);
      final payload = {
        'sandbox': false,
        'profileId': 'period-test',
        'chartTicket': 'TEST',
        'profileRecovered': true,
        'chartCalculatedAt': original.toIso8601String(),
        'result': {
          'data': {
            'nakshatra_details': {
              'chandra_rasi': {'name': 'Meena'},
              'nakshatra': {'name': 'Revati'},
            },
          },
        },
        'dashaPeriods': {
          'data': {
            'dasha_periods': [
              {
                'name': 'Mercury',
                'start': '2026-01-01T00:00:00Z',
                'end': '2027-01-01T00:00:00Z',
                'antardasha': [
                  {
                    'name': 'Venus',
                    'start': '2026-01-01T00:00:00Z',
                    'end': '2026-09-07T10:00:00Z',
                  },
                  {
                    'name': 'Sun',
                    'start': '2026-09-07T10:00:00Z',
                    'end': '2027-01-01T00:00:00Z',
                  },
                ],
              },
            ],
          },
        },
      };
      JyotaraApiClient client() => JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/astrology/kundli');
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {
              'set-cookie': 'nirayana_pilot_session=period-test; HttpOnly',
            },
          );
        }),
      );
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (v) async {
          disk = v;
        },
      );
      final first = ProfileSession(
        api: client(),
        vault: vault,
        clock: () => now,
      );
      await first.calculate(
        dateTime: '2000-01-01T12:00:00+05:30',
        latitude: 10,
        longitude: 78,
        exactTime: true,
      );
      expect(first.facts?['currentAntardasha']['name'], 'Venus');
      expect(first.calculatedAt, original);
      await first.flushStorage();
      now = now.add(const Duration(days: 2));
      final restored = ProfileSession(
        api: client(),
        vault: vault,
        clock: () => now,
      );
      await restored.restore();
      expect(restored.storageError, isNull);
      expect(restored.facts?['currentAntardasha']['name'], 'Venus');
      expect(restored.calculatedAt, original);
      expect(calls, 1);
    },
  );
}
