/// Suggestions are questions, never calculated conclusions. All taps use the
/// same request path as typed text. Only this conversation's history is used.
List<String> chatSuggestions(
  String category,
  String language,
  List<String> history,
) {
  var topic = category;
  for (final text in history) {
    final q = text.toLowerCase();
    if (RegExp(r'marriage|marry|kalyanam|திருமண').hasMatch(q)) {
      topic = 'Marriage';
    } else if (RegExp(r'career|job|velai|வேலை').hasMatch(q)) {
      topic = 'Career';
    } else if (RegExp(r'business|thozhil|வியாபார').hasMatch(q)) {
      topic = 'Business';
    } else if (RegExp(r'education|studies|study|padippu|படிப்பு').hasMatch(q)) {
      topic = 'Education';
    } else if (RegExp(r'love|relationship|kadhal|காதல்').hasMatch(q)) {
      topic = 'Love';
    }
  }
  const topics = {
    'Love': ['love', 'காதல்', 'love life'],
    'Relationships': ['relationships', 'உறவு', 'relationship'],
    'Marriage': ['marriage', 'திருமணம்', 'kalyanam'],
    'Family': ['family life', 'குடும்பம்', 'family'],
    'Career': ['work', 'வேலை', 'velai'],
    'Education': ['studies', 'படிப்பு', 'padippu'],
    'Business': ['business', 'தொழில்', 'business'],
    'Property': ['home and property', 'வீடு', 'veedu'],
    'Spiritual': ['spiritual reflection', 'ஆன்மிகம்', 'aanmigam'],
    'Daily': ['today', 'இன்று', 'innaiku'],
  };
  final names = topics[topic] ?? topics['Daily']!;
  final List<String> pool;
  if (language == 'tamil') {
    pool = [
      '${names[1]} பற்றி என் ஜாதகம் என்ன சொல்கிறது?',
      'எதில் கவனம் செலுத்த வேண்டும்?',
      'இப்போது என்ன செய்யலாம்?',
      'இதற்கான ஜாதகக் குறிப்பை விளக்க முடியுமா?',
      'இதை இன்னும் எளிதாகச் சொல்ல முடியுமா?',
      'என்னிடம் வேறு என்ன தெரிந்துகொள்ள வேண்டும்?',
    ];
  } else if (language == 'tanglish') {
    pool = [
      'En ${names[2]} pathi jathagam enna solludhu?',
      'Edhula konjam gavanama irukkanum?',
      'Ippo naan enna pannalaam?',
      'Idhuku jathagathula enna kurippu irukku?',
      'Innum simple ah sollunga?',
      'Enkitta vera enna therinjukkanum?',
    ];
  } else {
    pool = [
      'What does my chart suggest about ${names[0]}?',
      'What should I pay attention to?',
      'What can I do next?',
      'Which chart detail is this based on?',
      'Can you explain that more simply?',
      'What else would help you understand my situation?',
    ];
  }
  final unused = pool.where((p) => !history.contains(p)).toList();
  // Keep suggestions available even after exploring the complete set.
  return [
    ...unused,
    ...pool.where((p) => !unused.contains(p)),
  ].take(3).toList();
}
