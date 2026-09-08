import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/adult_birth_date.dart';

void main() {
  test('adult date picker follows India midnight and clamps leap-day cutoff', () {
    expect(latestAdultBirthDate(DateTime.utc(2026,9,6,18,29)),DateTime(2008,9,6));
    expect(latestAdultBirthDate(DateTime.utc(2026,9,6,18,30)),DateTime(2008,9,7));
    expect(latestAdultBirthDate(DateTime.utc(2024,2,29,8)),DateTime(2006,2,28));
  });
}
