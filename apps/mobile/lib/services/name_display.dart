/// Display-only Tamil transliteration. Never alters saved identity or birth data.
String tamilDisplayName(String value) {
  const known = {
    'saran': 'சரண்',
    'sharan': 'சரண்',
    'keerthi': 'கீர்த்தி',
    'meera': 'மீரா',
    'nila': 'நிலா',
    'aravind': 'அரவிந்த்',
    'adithya': 'ஆதித்யா',
    'kavya': 'காவ்யா',
    'janaki': 'ஜானகி',
    'revathi': 'ரேவதி',
    'karthik': 'கார்த்திக்',
  };
  const vowels = {
    'aa': ('ஆ', 'ா'),
    'ai': ('ஐ', 'ை'),
    'au': ('ஔ', 'ௌ'),
    'ee': ('ஈ', 'ீ'),
    'oo': ('ஊ', 'ூ'),
    'a': ('அ', ''),
    'e': ('எ', 'ெ'),
    'i': ('இ', 'ி'),
    'o': ('ஒ', 'ொ'),
    'u': ('உ', 'ு'),
  };
  const consonants = {
    'sh': 'ஷ',
    'ch': 'ச',
    'th': 'த',
    'dh': 'த',
    'zh': 'ழ',
    'ng': 'ங',
    'ny': 'ஞ',
    'kh': 'க',
    'ph': 'ப',
    'bh': 'ப',
    'gh': 'க',
    'k': 'க',
    'g': 'க',
    'c': 'ச',
    'j': 'ஜ',
    't': 'ட',
    'd': 'ட',
    'n': 'ந',
    'p': 'ப',
    'b': 'ப',
    'm': 'ம',
    'y': 'ய',
    'r': 'ர',
    'l': 'ல',
    'v': 'வ',
    'w': 'வ',
    's': 'ச',
    'h': 'ஹ',
    'f': 'ஃப',
    'z': 'ஸ',
    'q': 'க',
    'x': 'க்ஸ',
  };
  return value.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
    final word = match[0]!.toLowerCase();
    if (known.containsKey(word)) return known[word]!;
    final result = StringBuffer();
    var i = 0;
    String? findKey(Map map) {
      for (final key in map.keys) {
        if (word.startsWith(key, i)) return key as String;
      }
      return null;
    }

    while (i < word.length) {
      final vowel = findKey(vowels);
      if (vowel != null) {
        result.write(vowels[vowel]!.$1);
        i += vowel.length;
        continue;
      }
      final consonant = findKey(consonants);
      if (consonant == null) {
        i++;
        continue;
      }
      result.write(consonants[consonant]);
      i += consonant.length;
      final next = findKey(vowels);
      if (next == null) {
        result.write('்');
      } else {
        result.write(vowels[next]!.$2);
        i += next.length;
      }
    }
    return result.toString();
  });
}
