import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';

void main() {
  test(
    'twelve guides retain legacy identities and explicit category routing',
    () {
      expect(guides.length, 12);
      expect(guides.map((g) => g.name).toSet().length, 12);
      expect(guides.firstWhere((g) => g.name == 'Vetri').category, 'Career');
      expect(guides.firstWhere((g) => g.name == 'Valan').category, 'Business');
      expect(
        guides.firstWhere((g) => g.name == 'Iniya').category,
        'Relationships',
      );
      expect(guides.firstWhere((g) => g.name == 'Nila').category, 'Family');
      expect(guides.take(5).map((g) => g.name), [
        'Aadhirai',
        'Arivan',
        'Medha',
        'Tharagai',
        'Kaalam',
      ]);
    },
  );
}
