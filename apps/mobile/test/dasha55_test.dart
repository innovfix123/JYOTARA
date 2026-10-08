import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/explore_screen.dart';

void main() {
  test('Dasha boundaries display date only and retain India day', () {
    expect(dashaDate('2026-10-07T00:00:00+05:30'), '07/10/2026');
    expect(dashaDate('2026-10-06T18:30:00Z'), '07/10/2026');
    expect(dashaDate('not-a-date'), '—');
  });
}
