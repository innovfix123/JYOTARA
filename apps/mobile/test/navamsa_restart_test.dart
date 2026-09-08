import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/south_chart.dart';

// Synthetic-profile values from the successful 2026-09-07 provider response,
// not a real person's record. Only schema/positions retained, no provider prose.
const livePositions = [
  {'name': 'Rahu', 'rasi': 'Tula', 'position': 7, 'degree': 10.76127740702691},
  {
    'name': 'Mars',
    'rasi': 'Vrischika',
    'position': 8,
    'degree': 5.35615094041259,
  },
  {
    'name': 'Moon',
    'rasi': 'Meena',
    'position': 12,
    'degree': 0.3699184941256135,
  },
  {
    'name': 'Jupiter',
    'rasi': 'Mesha',
    'position': 1,
    'degree': 12.480767006432671,
  },
  {
    'name': 'Ketu',
    'rasi': 'Mesha',
    'position': 1,
    'degree': 10.761277407027137,
  },
  {
    'name': 'Mercury',
    'rasi': 'Mithuna',
    'position': 3,
    'degree': 9.081209854486588,
  },
  {'name': 'Sun', 'rasi': 'Simha', 'position': 5, 'degree': 26.503957269255807},
  {
    'name': 'Saturn',
    'rasi': 'Simha',
    'position': 5,
    'degree': 28.888787545956944,
  },
  {
    'name': 'Venus',
    'rasi': 'Kanya',
    'position': 6,
    'degree': 6.884963563407609,
  },
];
void main() {
  test('real D9 field projection survives save/restore without request or profile drift', () async {
    String? disk;
    var calls = 0;
    final vault = LocalProfileVault(
      read: () async => disk,
      write: (value) async {
        disk = value;
      },
    );
    const ids = {
      'Sun': 0,
      'Moon': 1,
      'Mercury': 2,
      'Venus': 3,
      'Mars': 4,
      'Jupiter': 5,
      'Saturn': 6,
      'Rahu': 101,
      'Ketu': 102,
    };
    final d9 = {
      'status': 'ok',
      'data': {
        'divisional_positions': List.generate(12, (offset) {
          final sign = (offset + 6) % 12;
          return {
            'rasi': {'id': sign, 'name': SouthIndianChart.signs[sign]},
            'planet_positions': livePositions
                .where((p) => p['position'] == sign + 1)
                .map(
                  (p) => {
                    'planet': {'id': ids[p['name']], 'name': p['name']},
                    'rasi': {'id': sign, 'name': p['rasi']},
                    'sign_degree': p['degree'],
                  },
                )
                .toList(),
          };
        }),
      },
    };
    final raw = {
      'sandbox': false,
      'profileId': 'D9-SYNTHETIC',
      'chartTicket': 'TEST-TICKET',
      'result': {
        'data': {
          'nakshatra_details': {
            'chandra_rasi': {'name': 'Meena'},
            'nakshatra': {'name': 'Uttara Bhadrapada'},
          },
        },
      },
      'navamsa': d9,
    };
    JyotaraApiClient api() => JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calls++;
        if (request.url.path == '/api/guidance') {
          final body = jsonDecode(request.body);
          expect(body['profileId'], 'D9-SYNTHETIC');
          expect(body['chartTicket'], 'TEST-TICKET');
          expect(request.headers['cookie'], 'nirayana_pilot_session=d9-test');
          return http.Response(
            jsonEncode({
              'profileId': 'D9-SYNTHETIC',
              'answer': 'Synthetic answer',
              'evidence': [],
            }),
            200,
          );
        }
        expect(request.url.path, '/api/astrology/kundli');
        return http.Response(
          jsonEncode(raw),
          200,
          headers: {'set-cookie': 'nirayana_pilot_session=d9-test; HttpOnly'},
        );
      }),
    );
    final first = ProfileSession(api: api(), vault: vault);
    await first.calculate(
      dateTime: '2000-01-01T12:00:00+05:30',
      latitude: 10,
      longitude: 78,
      exactTime: true,
    );
    final calculatedAt = first.calculatedAt;
    first
        .conversation('Arivan')
        .messages
        .add(const ChatMessage(fromUser: true, text: 'Career direction?'));
    first.conversation('Arivan').changed();
    await first.flushStorage();
    expect(first.facts?['navamsa'], livePositions);
    final restored = ProfileSession(api: api(), vault: vault);
    await restored.restore();
    expect(restored.storageError, isNull);
    expect(restored.facts?['navamsa'], livePositions);
    expect(restored.calculatedAt, calculatedAt);
    expect(
      restored.conversation('Arivan').messages.single.text,
      'Career direction?',
    );
    expect(
      calls,
      1,
      reason: 'Restore must not request D9 or any paid calculation',
    );
    await restored.ask(
      category: 'Career',
      question: 'Next step?',
      responseStyle: 'english',
    );
    expect(calls, 2, reason: 'Only explicit guidance is sent after restore');
    await restored.clear();
    final cleared = ProfileSession(api: api(), vault: vault);
    await cleared.restore();
    expect(cleared.facts, isNull);
    expect(calls, 2);
  });
}
