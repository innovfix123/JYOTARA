// Concise educational meanings, not individual predictions.
const planetMeanings = <String, (String, String)>{
  'Sun': (
    'Identity, confidence and how you take responsibility.',
    'தனித்தன்மை, தன்னம்பிக்கை, பொறுப்பேற்கும் விதம்.',
  ),
  'Moon': (
    'Feelings, comfort and your emotional needs.',
    'உணர்வுகள், ஆறுதல், மனத் தேவைகள்.',
  ),
  'Mars': (
    'Action, courage and how you handle challenges.',
    'செயல்பாடு, துணிவு, சவால்களை எதிர்கொள்ளும் விதம்.',
  ),
  'Mercury': (
    'Learning, thinking and how you communicate.',
    'கற்றல், சிந்தனை, பேசும் விதம்.',
  ),
  'Jupiter': (
    'Learning, values and a wider perspective.',
    'கற்றல், மதிப்புகள், பரந்த பார்வை.',
  ),
  'Venus': (
    'Affection, enjoyment and what you value in relationships.',
    'அன்பு, மகிழ்ச்சி, உறவுகளில் மதிப்பவை.',
  ),
  'Saturn': (
    'Patience, responsibilities and steady effort over time.',
    'பொறுமை, பொறுப்புகள், தொடர்ச்சியான முயற்சி.',
  ),
  'Rahu': (
    'Ambition, unfamiliar experiences and strong desires.',
    'லட்சியம், புதிய அனுபவங்கள், ஆழமான விருப்பங்கள்.',
  ),
  'Ketu': (
    'Reflection, letting go and inner understanding.',
    'சுயசிந்தனை, பற்றின்மை, உள்புரிதல்.',
  ),
};
const houseMeanings = <(String, String)>[
  (
    'Your identity and the way you approach life.',
    'உங்கள் தனித்தன்மையும் வாழ்க்கையை அணுகும் விதமும்.',
  ),
  (
    'Family background, speech and personal resources.',
    'குடும்பப் பின்னணி, பேச்சு, தனிப்பட்ட வளங்கள்.',
  ),
  (
    'Your effort, communication and sibling connections.',
    'முயற்சி, தொடர்பு, உடன்பிறந்தவர் உறவுகள்.',
  ),
  (
    'Home, roots and a sense of belonging.',
    'வீடு, வேர்கள், பாதுகாப்பான உணர்வு.',
  ),
  (
    'Creativity, learning, romance and children.',
    'படைப்பாற்றல், கற்றல், காதல், குழந்தைகள்.',
  ),
  (
    'Daily routines, service and handling everyday challenges.',
    'அன்றாட பழக்கங்கள், சேவை, சவால்களைச் சமாளித்தல்.',
  ),
  (
    'Marriage and other close partnerships.',
    'திருமணம் மற்றும் நெருக்கமான கூட்டுறவுகள்.',
  ),
  (
    'Change, shared resources and deeper questions.',
    'மாற்றம், பகிர்ந்த வளங்கள், ஆழமான கேள்விகள்.',
  ),
  (
    'Higher learning, beliefs and wider experiences.',
    'உயர்கல்வி, நம்பிக்கைகள், பரந்த அனுபவங்கள்.',
  ),
  (
    'Career, responsibilities and public roles.',
    'தொழில், பொறுப்புகள், சமூகப் பங்கு.',
  ),
  (
    'Friendships, communities and long-term goals.',
    'நட்பு, சமூக உறவுகள், நீண்டகால இலக்குகள்.',
  ),
  ('Rest, solitude and reflection.', 'ஓய்வு, தனிமை, சுயசிந்தனை.'),
];

String rasiTraitMeaning(String point) {
  const meanings = <String, (String, String, String)>{
    'Initiative': (
      'முன்முயற்சி',
      'Taking the first step instead of waiting for others.',
      'மற்றவர்களுக்காகக் காத்திருக்காமல் முதல் முயற்சியை எடுப்பது.',
    ),
    'Courage': (
      'துணிவு',
      'Facing a difficult situation even when you feel unsure.',
      'தயக்கம் இருந்தாலும் சவாலை எதிர்கொள்வது.',
    ),
    'Energy': (
      'ஆற்றல்',
      'Enthusiasm for starting and doing things.',
      'செயல்களைத் தொடங்குவதிலும் செய்வதிலும் ஆர்வம்.',
    ),
    'Patience': (
      'பொறுமை',
      'Giving things time without rushing.',
      'அவசரப்படாமல் தேவையான நேரத்தை அளிப்பது.',
    ),
    'Stability': (
      'நிலைத்தன்மை',
      'Valuing a steady routine and reliable relationships.',
      'நிலையான பழக்கங்களையும் நம்பகமான உறவுகளையும் விரும்புவது.',
    ),
    'Care': (
      'அக்கறை',
      'Noticing what people need and offering support.',
      'மற்றவர்களின் தேவையை அறிந்து உதவுவது.',
    ),
    'Curiosity': (
      'ஆர்வம்',
      'Wanting to ask questions and learn something new.',
      'கேள்விகள் கேட்டு புதியவற்றைக் கற்க விரும்புவது.',
    ),
    'Communication': (
      'உரையாடல்',
      'Sharing your thoughts and listening to others.',
      'உங்கள் எண்ணங்களைப் பகிர்ந்து மற்றவர்கள் சொல்வதைக் கேட்பது.',
    ),
    'Adaptability': (
      'நெகிழ்வு',
      'Adjusting when plans or circumstances change.',
      'திட்டங்களும் சூழ்நிலைகளும் மாறும்போது ஏற்றுக்கொள்வது.',
    ),
    'Belonging': (
      'பாசம்',
      'Feeling connected to family and close people.',
      'குடும்பத்துடனும் நெருங்கியவர்களுடனும் இணைந்திருப்பது.',
    ),
    'Sensitivity': (
      'உணர்வு',
      'Being aware of feelings and subtle changes around you.',
      'உணர்வுகளையும் சிறிய மாற்றங்களையும் கவனிப்பது.',
    ),
    'Confidence': (
      'தன்னம்பிக்கை',
      'Trusting yourself while staying open to feedback.',
      'பிறர் கருத்தையும் கேட்டு உங்களை நம்புவது.',
    ),
    'Expression': (
      'வெளிப்பாடு',
      'Showing your ideas and feelings openly.',
      'உங்கள் எண்ணங்களையும் உணர்வுகளையும் வெளிப்படுத்துவது.',
    ),
    'Leadership': (
      'தலைமை',
      'Helping people move towards a shared goal.',
      'பொதுவான இலக்கை நோக்கி மற்றவர்களை வழிநடத்துவது.',
    ),
    'Detail': (
      'நுணுக்கம்',
      'Paying attention to small things that matter.',
      'முக்கியமான சிறிய விஷயங்களைக் கவனிப்பது.',
    ),
    'Service': (
      'சேவை',
      'Helping others through useful actions.',
      'பயனுள்ள செயல்களால் மற்றவர்களுக்கு உதவுவது.',
    ),
    'Practicality': (
      'நடைமுறை',
      'Choosing steps that work in everyday life.',
      'அன்றாட வாழ்க்கைக்கு ஏற்ற வழிகளைத் தேர்ந்தெடுப்பது.',
    ),
    'Balance': (
      'சமநிலை',
      'Considering both sides before making a decision.',
      'முடிவெடுக்கும் முன் இரு பக்கங்களையும் சிந்திப்பது.',
    ),
    'Cooperation': (
      'ஒத்துழைப்பு',
      'Working together and sharing responsibility.',
      'ஒன்றாகச் செயல்பட்டு பொறுப்பைப் பகிர்வது.',
    ),
    'Harmony': (
      'இணக்கம்',
      'Finding respectful ways to handle disagreements.',
      'கருத்து வேறுபாடுகளை மரியாதையுடன் கையாள்வது.',
    ),
    'Depth': (
      'ஆழம்',
      'Looking beyond the surface to understand something.',
      'மேலோட்டமாக இல்லாமல் ஆழமாகப் புரிந்துகொள்வது.',
    ),
    'Determination': (
      'உறுதி',
      'Continuing your effort when a goal matters.',
      'முக்கியமான இலக்குக்காக தொடர்ந்து முயல்வது.',
    ),
    'Change': (
      'மாற்றம்',
      'Letting go of an old approach when a new one helps.',
      'புதிய வழி உதவும்போது பழைய வழியை மாற்றுவது.',
    ),
    'Learning': (
      'கற்றல்',
      'Building understanding through practice and questions.',
      'பயிற்சி மற்றும் கேள்விகளால் புரிதலை வளர்ப்பது.',
    ),
    'Exploration': (
      'தேடல்',
      'Trying new ideas and experiences.',
      'புதிய எண்ணங்களையும் அனுபவங்களையும் முயல்வது.',
    ),
    'Meaning': (
      'நோக்கம்',
      'Connecting your choices with what matters to you.',
      'உங்கள் தேர்வுகளை உங்களுக்கு முக்கியமானவற்றுடன் இணைப்பது.',
    ),
    'Discipline': (
      'ஒழுக்கம்',
      'Following through on a plan with regular effort.',
      'திட்டமிட்டபடி தொடர்ந்து முயல்வது.',
    ),
    'Responsibility': (
      'பொறுப்பு',
      'Taking care of commitments and their consequences.',
      'கடமைகளையும் அதன் விளைவுகளையும் பொறுப்புடன் கையாள்வது.',
    ),
    'Ideas': (
      'சிந்தனை',
      'Considering a fresh way to solve a problem.',
      'சிக்கலைத் தீர்க்க புதிய வழியைச் சிந்திப்பது.',
    ),
    'Community': (
      'சமூகம்',
      'Caring about shared needs and supporting a group.',
      'பொதுத் தேவைகளில் அக்கறையுடன் குழுவுக்கு உதவுவது.',
    ),
    'Independence': (
      'சுதந்திரம்',
      'Making your own choices while respecting others.',
      'மற்றவர்களை மதித்து உங்கள் முடிவுகளை எடுப்பது.',
    ),
    'Compassion': (
      'அன்பு',
      'Responding kindly when someone is struggling.',
      'ஒருவர் சிரமப்படும்போது அன்புடன் உதவுவது.',
    ),
    'Imagination': (
      'கற்பனை',
      'Thinking creatively about possibilities.',
      'சாத்தியங்களைப் புதுமையாகச் சிந்திப்பது.',
    ),
  };
  for (final entry in meanings.entries) {
    if (entry.key == point)
      return '${entry.value.$2}\n\nA traditional Rasi theme, not a fixed description of everyone.';
    if (entry.value.$1 == point ||
        (entry.key == 'Sensitivity' && point == 'மென்மையான மனம்'))
      return '${entry.value.$3}\n\nஇது பாரம்பரிய ராசிக் கருத்து; அனைவருக்கும் ஒரே இயல்பு இருக்காது.';
  }
  return point;
}
