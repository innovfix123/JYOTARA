import 'chart_facts.dart';
import 'jyotara_api.dart';

String matchingBirthKey(Map<String, dynamic> person) =>
    '${person['datetime']}|${person['latitude']}|${person['longitude']}|${person['exactTime']}';

/// Uses the existing authenticated chart service. It never infers a Moon sign
/// from names or solar birthday ranges and never blocks the paid comparison.
Future<String?> loadMatchingRasi(
  Map<String, dynamic> person, {
  String? Function()? phoneToken,
  String? Function()? testerCode,
}) async {
  final api = JyotaraApiClient(phoneToken: phoneToken, testerCode: testerCode);
  try {
    final response = await api.calculateChart(
      dateTime: person['datetime'] as String,
      latitude: (person['latitude'] as num).toDouble(),
      longitude: (person['longitude'] as num).toDouble(),
      birthTimeKnown: person['exactTime'] == true,
      currentDateTime: DateTime.now().toUtc().toIso8601String(),
      language: 'en',
    );
    final facts = normalizeChartFacts(
      response.chart,
      birthTimeKnown: person['exactTime'] == true,
      at: DateTime.now().toUtc(),
    );
    return facts['rashi'] as String?;
  } finally {
    api.close();
  }
}
