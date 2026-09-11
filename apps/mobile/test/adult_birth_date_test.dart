import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/adult_birth_date.dart';

void main() {
  test('13+ date picker follows India midnight and clamps leap-day cutoff', () {
    expect(latestEligibleBirthDate(DateTime.utc(2026,9,6,18,29)),DateTime(2013,9,6));
    expect(latestEligibleBirthDate(DateTime.utc(2026,9,6,18,30)),DateTime(2013,9,7));
    expect(latestEligibleBirthDate(DateTime.utc(2024,2,29,8)),DateTime(2011,2,28));
  });
}
