import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/full_name.dart';

void main() {
  test('accepts Unicode names, initials and unfamiliar genuine names', () {
    for (final name in [
      'Saran',
      'Saran Keerthi',
      'R Saran',
      'சரண் கீர்த்தி',
      'Élodie',
      'Ng',
      'Srinivasan',
      '  Saran  Keerthi  ',
    ]) {
      expect(validFullName(name), isTrue, reason: name);
    }
  });
  test('rejects empty, digits, symbols and obvious keyboard placeholders', () {
    for (final name in [
      '',
      ' ',
      'A',
      'Saran123',
      '@Saran',
      'qwerty',
      'test',
      'dummy troll',
      'aaaaaa',
      'chhvjvjvhfjvjchdhfhfgjv',
    ]) {
      expect(validFullName(name), isFalse, reason: name);
    }
  });
}
