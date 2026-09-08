import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/chart_display.dart';

void main() {
  test('planet values remain readable without crossing a sign boundary', () {
    expect(displayPlanetDegree(4.048134641811998), '4.05°');
    expect(displayPlanetDegree(0), '0.00°');
    expect(displayPlanetDegree(29.999999), '>29.99°');
    for (final value in [null, double.nan, double.infinity, -1, 30, '4.5']) {
      expect(displayPlanetDegree(value), 'Unavailable');
    }
  });
  test('timestamps carry explicit India timezone and handle date rollover', () {
    expect(
      displayIndiaTimestamp('2026-09-05T20:00:00Z'),
      '06 Sep 2026, 01:30 IST (UTC+05:30)',
    );
    expect(
      displayIndiaTimestamp('2026-09-06T01:30:00+05:30'),
      '06 Sep 2026, 01:30 IST (UTC+05:30)',
    );
    expect(
      displayIndiaTimestamp(DateTime.utc(2026, 9, 5, 20)),
      '06 Sep 2026, 01:30 IST (UTC+05:30)',
    );
    expect(displayIndiaTimestamp('2026-09-05T20:00:00'), 'Unavailable');
    expect(displayIndiaTimestamp(null), 'Unavailable');
  });
}
