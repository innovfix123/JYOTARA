import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/chart_facts.dart';

void main() {
  final at = DateTime.utc(2026, 9, 5);
  Map<String, dynamic> fixture() => {
    'sandbox': false,
    'result': {
      'data': {
        'nakshatra_details': {
          'chandra_rasi': {'name': 'Meena'},
          'nakshatra': {'name': 'Uttara Bhadrapada', 'pada': 1},
        },
      },
    },
    'planetPosition': {
      'data': {
        'planet_position': [
          {
            'id': 100,
            'name': 'Ascendant',
            'rasi': {'name': 'Mithuna'},
          },
          {
            'id': 1,
            'name': 'Moon',
            'rasi': {'name': 'Meena'},
            'degree': 4.5,
            'position': 12,
          },
          {
            'id': 2,
            'name': 'Mars',
            'rasi': {'name': 'Karka'},
          },
        ],
      },
    },
    'dashaPeriods': {
      'data': {
        'dasha_periods': [
          {
            'name': 'Mercury',
            'start': '2020-01-01T00:00:00Z',
            'end': '2030-01-01T00:00:00Z',
          },
        ],
      },
    },
    'panchang': {
      'data': {
        'tithi': [
          {
            'name': 'Expired',
            'start': '2020-01-01T00:00:00Z',
            'end': '2020-01-02T00:00:00Z',
          },
        ],
      },
    },
  };
  test('valid facts are mapped without invented zero-degree planets or stale timings', () {
    final facts = normalizeChartFacts(fixture(), birthTimeKnown: true, at: at);
    expect(facts['lagna'], 'Mithuna');
    expect((facts['planets'] as List).length, 1);
    expect(facts['currentDasha']['name'], 'Mercury');
    expect(facts['todayPanchang'].containsKey('tithi'), false);
  });
  test('unknown time withholds Lagna and Dasa', () {
    final facts = normalizeChartFacts(fixture(), birthTimeKnown: false, at: at);
    expect(facts.containsKey('lagna'), false);
    expect(facts.containsKey('currentDasha'), false);
  });
  test('overlapping periods and out-of-parent Bhukti are withheld', () {
    final payload = fixture();
    final periods = <Map<String, dynamic>>[
      Map<String, dynamic>.from(payload['dashaPeriods']['data']['dasha_periods'][0]),
    ];
    payload['dashaPeriods'] = {'data': {'dasha_periods': periods}};
    final parent = periods.single;
    parent['antardasha'] = [
      {
        'name': 'Venus',
        'start': '2025-01-01T00:00:00Z',
        'end': '2028-01-01T00:00:00Z',
      },
    ];
    Map<String, dynamic> convert() =>
        normalizeChartFacts(payload, birthTimeKnown: true, at: at);
    expect(convert()['currentAntardasha']['name'], 'Venus');
    parent['antardasha'][0]['end'] = '2031-01-01T00:00:00Z';
    expect(convert().containsKey('currentAntardasha'), false);
    parent['antardasha'][0]['end'] = '2028-01-01T00:00:00Z';
    parent['antardasha'].add(Map<String, String>.from(parent['antardasha'][0]));
    expect(convert().containsKey('currentAntardasha'), false);
    periods.add({...parent, 'name': 'Saturn'});
    expect(convert().containsKey('currentDasha'), false);
    expect(convert().containsKey('currentAntardasha'), false);
  });
  test('planet position is a sign number, not longitude', () {
    final payload = fixture();
    final rows = payload['planetPosition']['data']['planet_position'] as List;
    rows.add({
      'id': 3,
      'name': 'Mercury',
      'rasi': {'name': 'Meena'},
      'degree': 4.5,
      'position': 334.5,
    });
    rows.add({
      'id': 4,
      'name': 'Venus',
      'rasi': {'name': 'Meena'},
      'degree': 31,
      'position': 12,
    });
    final facts = normalizeChartFacts(payload, birthTimeKnown: true, at: at);
    expect((facts['planets'] as List).length, 1);
    expect(facts['planets'][0]['position'], 12);
  });
  test(
    'context timestamp is preserved, never refreshed from the client clock',
    () {
      const original = '2026-09-04T12:00:00Z';
      final facts = normalizeChartFacts(
        {...fixture(), 'contextCalculatedAt': original},
        birthTimeKnown: true,
        at: at,
      );
      expect(facts['contextCalculatedAt'], original);
      expect(
        normalizeChartFacts(
          fixture(),
          birthTimeKnown: true,
          at: at,
        ).containsKey('contextCalculatedAt'),
        false,
      );
    },
  );
  test(
    'sandbox and incomplete identity cannot be presented as live charts',
    () {
      expect(
        () => normalizeChartFacts(
          {...fixture(), 'sandbox': true},
          birthTimeKnown: true,
          at: at,
        ),
        throwsFormatException,
      );
      expect(
        () => normalizeChartFacts(
          {'sandbox': false},
          birthTimeKnown: true,
          at: at,
        ),
        throwsFormatException,
      );
    },
  );
}
