import 'chart_instant.dart';

/// Keep actual nested provider checks, not group headings. Absence is a
/// boolean fact; malformed/ambiguous or unknown-time results are withheld.
List<Map<String, dynamic>>? normalizeYogaAssessments(dynamic groups, bool known) {
  if (!known || groups is! List || groups.length > 20) return null;
  final result = <Map<String, dynamic>>[];
  final seen = <String>{};
  bool validName(dynamic value) => value is String && value.trim().isNotEmpty &&
      value.length <= 80 && !RegExp(r'[\u0000-\u001f]').hasMatch(value);
  for (final group in groups) {
    if (group is! Map || !validName(group['name']) || group['yoga_list'] is! List) return null;
    for (final item in group['yoga_list'] as List) {
      if (item is! Map || !validName(item['name']) || item['has_yoga'] is! bool ||
          item['description'] is! String || (item['description'] as String).length > 8000) {
        return null;
      }
      final key = (item['name'] as String).trim().toLowerCase();
      if (!seen.add(key) || result.length >= 100) return null;
      result.add({'name': (item['name'] as String).trim(), 'description': item['description'],
        'group': (group['name'] as String).trim(), 'present': item['has_yoga']});
    }
  }
  return result;
}

/// D9's zero-based sign IDs differ from natal position. Keep it separate and
/// omit the whole optional module on ambiguity; never invent missing planets.
List<Map<String, dynamic>>? normalizeNavamsa(dynamic payload, bool known) {
  if (!known || payload is! Map || payload['status'] != 'ok') return null;
  final data = payload['data'];
  if (data is! Map) return null;
  final groups = data['divisional_positions'];
  if (groups is! List || groups.length != 12) return null;
  const signs = [
    'Mesha',
    'Vrishabha',
    'Mithuna',
    'Karka',
    'Simha',
    'Kanya',
    'Tula',
    'Vrischika',
    'Dhanu',
    'Makara',
    'Kumbha',
    'Meena',
  ];
  const names = {
    0: 'Sun',
    1: 'Moon',
    2: 'Mercury',
    3: 'Venus',
    4: 'Mars',
    5: 'Jupiter',
    6: 'Saturn',
    100: 'Ascendant',
    101: 'Rahu',
    102: 'Ketu',
  };
  final seenSigns = <int>{};
  final seenPlanets = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final group in groups) {
    if (group is! Map || group['rasi'] is! Map) return null;
    final sign = group['rasi'] as Map;
    final id = sign['id'];
    if (id is! int ||
        id < 0 ||
        id > 11 ||
        signs[id] != sign['name'] ||
        !seenSigns.add(id)) {
      return null;
    }
    final planets = group['planet_positions'];
    if (planets is! List) return null;
    for (final item in planets) {
      if (item is! Map || item['planet'] is! Map || item['rasi'] is! Map) {
        return null;
      }
      final planet = item['planet'] as Map;
      final rasi = item['rasi'] as Map;
      final name = names[planet['id']];
      final degree = item['sign_degree'];
      if (name == null ||
          planet['name'] != name ||
          !seenPlanets.add(name) ||
          rasi['id'] != id ||
          rasi['name'] != signs[id] ||
          degree is! num ||
          !degree.isFinite ||
          degree < 0 ||
          degree >= 30) {
        return null;
      }
      if (planet['id'] != 100) {
        result.add({
          'name': name,
          'rasi': signs[id],
          'position': id + 1,
          'degree': degree,
        });
      }
    }
  }
  return result.length == 9 ? result : null;
}

/// Converts the protected backend's Prokerala payload into guidance facts.
/// Missing values stay absent; mock calculations never become personal facts.
Map<String, dynamic> normalizeChartFacts(
  Map<String, dynamic> payload, {
  required bool birthTimeKnown,
  required DateTime at,
}) {
  if (payload['sandbox'] != false) {
    throw const FormatException('A confirmed production chart is required.');
  }
  Map<String, dynamic> object(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  List<Map<String, dynamic>> list(dynamic value) =>
      value is List ? value.whereType<Map>().map(object).toList() : [];
  String? name(dynamic value) {
    final result = object(value)['name'];
    return result is String && result.trim().isNotEmpty ? result : null;
  }

  Map<String, dynamic> data(String key) => object(object(payload[key])['data']);
  bool current(Map<String, dynamic> item) {
    final start = parseChartInstant(item['start']);
    final end = parseChartInstant(item['end']);
    return start != null &&
        end != null &&
        !at.isBefore(start) &&
        at.isBefore(end);
  }

  Map<String, dynamic>? active(dynamic value) {
    final matches = list(value).where(current).toList();
    return matches.length == 1 ? matches.single : null;
  }

  Map<String, dynamic>? period(Map<String, dynamic>? value) =>
      value != null && name(value) != null
      ? {'name': name(value), 'start': value['start'], 'end': value['end']}
      : null;
  List<Map<String, dynamic>> planets(String key) {
    return list(data(key)['planet_position'])
        .where((item) {
          final degree = item['degree'];
          final position = item['position'];
          return item['id'] != 100 &&
              name(item) != null &&
              name(item['rasi']) != null &&
              degree is num &&
              degree.isFinite &&
              degree >= 0 &&
              degree < 30 &&
              position is num &&
              position.isFinite &&
              position == position.roundToDouble() &&
              position >= 1 &&
              position <= 12;
        })
        .map(
          (item) => <String, dynamic>{
            'name': name(item),
            'rasi': name(item['rasi']),
            'degree': item['degree'],
            'position': item['position'],
            'isRetrograde': item['is_retrograde'] == true,
          },
        )
        .toList();
  }

  final kundli = data('result');
  final yogaAssessments = normalizeYogaAssessments(kundli['yoga_details'], birthTimeKnown);
  final details = object(kundli['nakshatra_details']);
  final moon = object(details['chandra_rasi']);
  final star = object(details['nakshatra']);
  final natal = list(data('planetPosition')['planet_position']);
  final ascendants = natal.where((item) => item['id'] == 100);
  final ascendant = ascendants.isEmpty
      ? <String, dynamic>{}
      : object(ascendants.first['rasi']);
  final dasha = birthTimeKnown
      ? active(data('dashaPeriods')['dasha_periods'])
      : null;
  var bhukti = dasha == null ? null : active(dasha['antardasha']);
  if (bhukti != null &&
      dasha != null &&
      (parseChartInstant(bhukti['start'])!
              .isBefore(parseChartInstant(dasha['start'])!) ||
          parseChartInstant(bhukti['end'])!
              .isAfter(parseChartInstant(dasha['end'])!))) {
    bhukti = null;
  }
  final panchang = data('panchang');
  final tithi = active(panchang['tithi']);
  final facts = <String, dynamic>{
    'rashi': ?name(moon),
    'rashiLord': ?name(moon['lord']),
    'nakshatra': ?name(star),
    'nakshatraLord': ?name(star['lord']),
    if (star['pada'] is int && star['pada'] >= 1 && star['pada'] <= 4)
      'pada': star['pada'],
    if (birthTimeKnown) 'lagna': ?name(ascendant),
    if (birthTimeKnown) 'lagnaLord': ?name(ascendant['lord']),
    'planets': planets('planetPosition'),
    'navamsa': ?normalizeNavamsa(payload['navamsa'], birthTimeKnown),
    'transits': planets('transitPosition'),
    if (payload['contextCalculatedAt'] is String)
      'contextCalculatedAt': payload['contextCalculatedAt'],
    'yogas': (yogaAssessments ?? <Map<String, dynamic>>[])
        .where((item) => item['present'] == true)
        .map((item) => {'name': item['name'], 'description': item['description']}).toList(),
    'yogaAssessments': ?yogaAssessments,
    'currentDasha': ?period(dasha),
    'currentAntardasha': ?period(bhukti),
    if (panchang.isNotEmpty)
      'todayPanchang': {
        if (panchang['vaara'] is String) 'vaara': panchang['vaara'],
        'tithi': ?name(tithi),
        'nakshatra': ?name(active(panchang['nakshatra'])),
        'yoga': ?name(active(panchang['yoga'])),
        'karana': ?name(active(panchang['karana'])),
      },
  };
  if (facts['rashi'] == null || facts['nakshatra'] == null) {
    throw const FormatException(
      'The calculation did not return birth-chart identity.',
    );
  }
  return facts;
}
