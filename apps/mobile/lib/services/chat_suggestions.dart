/// Suggestions are questions, never calculated conclusions. All taps use the
/// same request path as typed text. Only this conversation's history is used.
List<String> chatSuggestions(
  String category,
  String language,
  List<String> history, {
  String? lastReply,
}) {
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
  final index = language == 'tamil'
      ? 1
      : language == 'tanglish'
      ? 2
      : 0;
  // Topic-specific questions are invitations, never invented user facts.
  const followups = {
    "Love": [
      [
        "When is commitment favoured?",
        "காதல் உறுதி பெறும் காலம் எப்போது?",
        "Love urudhiyaaga eppo vaaippu?",
      ],
      [
        "Which planet affects my love life?",
        "என் காதலை எந்த கிரகம் பாதிக்கிறது?",
        "En love-ai endha graham paathikkudhu?",
      ],
      [
        "Does my chart show a delay?",
        "என் ஜாதகத்தில் தாமதம் இருக்கிறதா?",
        "En jathagathula thaamadham irukka?",
      ],
    ],
    "Marriage": [
      [
        "When is marriage favoured?",
        "திருமணத்திற்கு ஏற்ற காலம் எப்போது?",
        "Kalyanam nadakka eppo vaaippu?",
      ],
      [
        "What does my chart say about family support?",
        "குடும்ப ஆதரவு பற்றி என் ஜாதகம் என்ன சொல்கிறது?",
        "Kudumba aadharavu pathi jathagam enna solludhu?",
      ],
      [
        "What does my seventh house indicate?",
        "என் ஏழாம் பாவம் என்ன சொல்கிறது?",
        "En ezhaam paavam enna solludhu?",
      ],
    ],
    "Career": [
      [
        "When is a work change favoured?",
        "வேலை மாற்றத்திற்கு ஏற்ற காலம் எப்போது?",
        "Velai maara eppo vaaippu?",
      ],
      [
        "Which career strengths does my chart show?",
        "எந்த வேலைக்கான பலம் என் ஜாதகத்தில் உள்ளது?",
        "Endha velaikku en jathagathula balam irukku?",
      ],
      [
        "What does my current dasha indicate for work?",
        "தற்போதைய தசை வேலை பற்றி என்ன சொல்கிறது?",
        "Ippodhaiya dasai velai pathi enna solludhu?",
      ],
    ],
    "Education": [
      [
        "What does my chart suggest for higher studies?",
        "மேற்படிப்பு பற்றி என் ஜாதகம் என்ன சொல்கிறது?",
        "Higher studies pathi en jathagam enna solludhu?",
      ],
      [
        "Which planet supports my studies?",
        "என் படிப்புக்கு எந்த கிரகத்தின் ஆதரவு உள்ளது?",
        "En padippukku endha graha aadharavu irukku?",
      ],
      [
        "Is this a favourable study period?",
        "இது படிப்பிற்கு சாதகமான காலமா?",
        "Idhu padippukku saadhagamaana kaalama?",
      ],
    ],
    "Business": [
      [
        "Is this a favourable time to start a business?",
        "தொழில் தொடங்க இது சாதகமான காலமா?",
        "Business aarambikka idhu saadhagamaana kaalama?",
      ],
      [
        "What does my chart say about partnerships?",
        "கூட்டுத் தொழில் பற்றி என் ஜாதகம் என்ன சொல்கிறது?",
        "Kootu thozhil pathi en jathagam enna solludhu?",
      ],
      [
        "Which period supports business growth?",
        "தொழில் வளர்ச்சிக்கு எந்த காலம் சாதகமாக உள்ளது?",
        "Business valarchikku endha kaalam saadhagam?",
      ],
    ],
  };
  const situational = {
    'money': [
      [
        'How can I refuse a money request respectfully?',
        'பணம் கொடுக்க முடியாது என்று மரியாதையாக எப்படி சொல்வது?',
        'Panam kudukka mudiyaadhunu mariyadhaiya eppadi solradhu?',
      ],
      [
        'How can I recognise pressure around money?',
        'பணம் தொடர்பான அழுத்தத்தை எப்படி அடையாளம் காண்பது?',
        'Panam vishayathula pressure-a eppadi kandupidikkaradhu?',
      ],
      [
        'What if my financial boundary is ignored?',
        'என் பண வரம்பை மதிக்காவிட்டால் என்ன செய்யலாம்?',
        'En panam sambandhamaana varambai madhikkalaina enna seiyalaam?',
      ],
    ],
    'family': [
      [
        'How can I start this conversation with my parents?',
        'பெற்றோரிடம் இந்தப் பேச்சை எப்படி தொடங்குவது?',
        'Parents kitta indha pechai eppadi aarambikkaradhu?',
      ],
      [
        'How can I understand their concerns?',
        'அவர்களின் கவலையை எப்படி புரிந்துகொள்வது?',
        'Avanga kavalaiya eppadi purinjukkaradhu?',
      ],
      [
        'What if we need more time to decide?',
        'முடிவெடுக்க இன்னும் நேரம் தேவைப்பட்டால் என்ன செய்வது?',
        'Mudivedukka innum neram thevaipatta enna panradhu?',
      ],
    ],
    'reply': [
      [
        'How can we agree on a comfortable time to talk?',
        'இருவருக்கும் வசதியாகப் பேசும் நேரத்தை எப்படி முடிவு செய்வது?',
        'Rendu perukkum vasadhiya pesa neram eppadi mudivu panradhu?',
      ],
      [
        'How can I explain my communication needs?',
        'என் தொடர்பு எதிர்பார்ப்பை எப்படி விளக்குவது?',
        'En communication thevaiyai eppadi solradhu?',
      ],
      [
        'How can I distinguish being busy from avoiding me?',
        'வேலைப்பளுவுக்கும் என்னைத் தவிர்ப்பதற்கும் உள்ள வேறுபாட்டை எப்படி அறிவது?',
        'Busy-a irukkaradhukkum avoid panradhukkum vithiyasam eppadi theriyum?',
      ],
    ],
  };
  final latest = history.isEmpty ? '' : history.last.toLowerCase();
  final generic = RegExp(r'simply|simple|explain|next|எளிதாக|விளக்க')
      .hasMatch(latest);
  final context = generic ? '$latest ${lastReply ?? ''}'.toLowerCase() : latest;
  String? situation;
  if (['Love', 'Relationships', 'Marriage', 'Family'].contains(topic)) {
    if (RegExp(r'money|panam|பணம்').hasMatch(context)) {
      situation = 'money';
    } else if (RegExp(r'parent|family|appa|amma|veetl|பெற்றோர்|அப்பா|வீட்டில்')
        .hasMatch(context)) {
      situation = 'family';
    } else if (RegExp(r'reply|text|shift|பதில்|பேசும் நேரம்')
        .hasMatch(context)) {
      situation = 'reply';
    }
  }
  final starter = [
    'What does my chart suggest about ${names[0]}?',
    '${names[1]} பற்றி என் ஜாதகம் என்ன சொல்கிறது?',
    'En ${names[2]} pathi jathagam enna solludhu?',
  ][index];
  final selected = situation != null
      ? situational[situation]!
      : followups[topic == 'Relationships' ? 'Love' : topic];
  final pool = <String>[
    if (history.isEmpty) starter,
    if (selected != null) ...selected.map((row) => row[index]),
    if (selected == null) ...[
      [
        'Which ${names[0]} concern should we explore?',
        '${names[1]} தொடர்பாக எந்தக் கவலையைப் பேசலாம்?',
        '${names[2]} sambandhama endha kavalaiya pesalaam?',
      ][index],
      [
        'How can I weigh my options for ${names[0]}?',
        '${names[1]} தொடர்பான தேர்வுகளை எப்படி மதிப்பிடுவது?',
        '${names[2]} sambandhamaana options-a eppadi yosikkaradhu?',
      ][index],
      [
        'What information would help with my ${names[0]} question?',
        '${names[1]} கேள்விக்கு எந்த விவரம் உதவும்?',
        '${names[2]} kelvikku endha vivaram udhavum?',
      ][index],
    ],
  ];
  String normalized(String text) => text.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  final used = history.map(normalized).toSet();
  // Never recycle an exhausted bank. Typing remains available.
  return pool.where((p) => !used.contains(normalized(p))).take(3).toList();
}
