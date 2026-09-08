/// Conservative convenience detection, not a substitute for the user's
/// explicit reply-language choice. Match whole words, never substrings of
/// English words, names, URLs or email addresses.
String detectReplyLanguage(String question, {String preference = 'auto'}) {
  if (const {'english', 'tamil', 'tanglish'}.contains(preference)) {
    return preference;
  }
  final text = question.replaceAll(
    RegExp(r'https?://\S+|www\.\S+|[^\s@]+@[^\s@]+', caseSensitive: false),
    ' ',
  );
  if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'tamil';
  final words = RegExp(r'[a-z]+')
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .toSet();
  const markers = {
    'enaku', 'enakku', 'ennaku', 'enna', 'eppo', 'eppodhu',
    'epdi', 'eppadi', 'iruka', 'irukka', 'iruku', 'irukku',
    'panna', 'pannanum', 'aaguma', 'aguma', 'venum', 'vendum',
    'sollu', 'sollunga', 'nalla', 'innaiku', 'inniku',
    'kedaikuma', 'kidaikuma', 'nadakkum', 'velai', 'velaila',
  };
  // “yen” is also an English currency word: it cannot select Tanglish alone.
  return words.any(markers.contains) ? 'tanglish' : 'english';
}
