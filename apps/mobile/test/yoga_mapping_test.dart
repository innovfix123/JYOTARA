import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/chart_facts.dart';

void main() {
  List<Map<String, dynamic>> groups() => [{'name': 'Major Yogas', 'description': 'Summary only', 'yoga_list': [
    {'name': 'Raja Yoga', 'has_yoga': true, 'description': 'Synthetic present explanation'},
    {'name': 'Hamsa Yoga', 'has_yoga': false, 'description': 'Synthetic absent explanation'},
  ]}];
  test('nested yoga names and boolean absence are preserved, not group summaries', () {
    final result = normalizeYogaAssessments(groups(), true)!;
    expect(result, hasLength(2));
    expect(result.first['name'], 'Raja Yoga');
    expect(result.first['present'], true);
    expect(result.last['present'], false);
    expect(result.every((r) => r['name'] != 'Major Yogas'), true);
    expect(normalizeYogaAssessments(groups(), false), isNull);
  });
  test('invalid yoga status and duplicate checks withhold the optional module', () {
    final stringStatus = groups();
    (stringStatus.first['yoga_list'] as List).first['has_yoga'] = 'true';
    expect(normalizeYogaAssessments(stringStatus, true), isNull);
    final duplicate = groups();
    (duplicate.first['yoga_list'] as List).add({'name': 'Raja Yoga', 'has_yoga': false, 'description': 'Conflict'});
    expect(normalizeYogaAssessments(duplicate, true), isNull);
    expect(normalizeYogaAssessments([{'name': 'Heading only'}], true), isNull);
  });
}
