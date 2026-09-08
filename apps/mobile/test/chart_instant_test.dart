import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/chart_instant.dart';
import 'package:jyotara/services/chart_display.dart';

void main() {
  test('strict calendar, clock and timezone validation', () {
    for (final invalid in [
      '2026-02-29T00:00:00Z',
      '2026-04-31T00:00:00Z',
      '2026-00-01T00:00:00Z',
      '2026-01-00T00:00:00Z',
      '2026-01-01T24:00:00Z',
      '2026-01-01T00:60:00Z',
      '2026-01-01T00:00:60Z',
      '2026-01-01T00:00:00+24:00',
      '2026-01-01T00:00:00+05:60',
      '2026-01-01T00:00:00',
      '2026-01-01',
      '',
      null,
    ]) {
      expect(parseChartInstant(invalid), isNull, reason: '$invalid');
      expect(displayIndiaTimestamp(invalid), 'Unavailable');
    }
    expect(
      parseChartInstant('2024-02-29T05:30:00+05:30'),
      DateTime.utc(2024, 2, 29),
    );
    expect(
      parseChartInstant('2026-01-01T00:00:00.123456Z'),
      DateTime.utc(2026, 1, 1, 0, 0, 0, 123, 456),
    );
  });
}
