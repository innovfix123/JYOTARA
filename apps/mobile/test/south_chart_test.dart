import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/south_chart.dart';

void main() {
  test('South Indian perimeter contains every sign once', () {
    final cells = SouthIndianChart.cells.where((cell) => cell >= 0).toList()
      ..sort();
    expect(cells, List.generate(12, (index) => index));
    expect(SouthIndianChart.cells.first, 11);
    expect(SouthIndianChart.signIndex('Karka'), 3);
    expect(SouthIndianChart.signIndex('Mithuna'), 2);
    expect(SouthIndianChart.signIndex('unknown'), -1);
  });
}
