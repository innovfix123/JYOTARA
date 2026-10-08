/// Conservative validation: accept Unicode names and initials, never infer
/// identity from vowel patterns in Tamil or reject unfamiliar genuine names.
bool validFullName(String value) {
  final name = value.trim().replaceAll(RegExp(r' +'), ' ');
  if (name.length > 60 ||
      !RegExp(r'^[\p{L}\p{M} ]+$', unicode: true).hasMatch(name)) {
    return false;
  }
  if (RegExp(r'\p{L}', unicode: true).allMatches(name).length < 2) return false;
  final words = name.toLowerCase().split(' ');
  const placeholders = {
    'test',
    'testing',
    'dummy',
    'fake',
    'troll',
    'asdf',
    'asdfgh',
    'qwerty',
    'qwertyuiop',
    'abc',
    'abcd',
    'abcdef',
  };
  if (words.every(placeholders.contains)) return false;
  for (final word in words) {
    if (RegExp(r'([a-z])\1{4,}').hasMatch(word)) return false;
    if (word.length >= 12 &&
        RegExp(r'^[a-z]+$').hasMatch(word) &&
        !RegExp(r'[aeiouy]').hasMatch(word)) {
      return false;
    }
  }
  return true;
}
