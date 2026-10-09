import '../bronze_theme.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI language is deliberately separate from reply language and consent.
class UiLanguagePreferences extends ChangeNotifier {
  UiLanguagePreferences({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _read =
           read ??
           (() =>
               SharedPreferencesAsync().getString('nirayana.ui_language.v1')),
       _write =
           write ??
           ((v) => SharedPreferencesAsync().setString(
             'nirayana.ui_language.v1',
             v,
           ));
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  String value = 'en';
  Future<void> _pending = Future.value();
  Future<void> load() async {
    value = await _read() == 'ta' ? 'ta' : 'en';
    notifyListeners();
  }

  Future<void> set(String value) {
    if (!{'en', 'ta'}.contains(value)) {
      return Future.error(ArgumentError('Unsupported UI language'));
    }
    final operation = _pending.then((_) async {
      await _write(value);
      this.value = value;
      notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

class UiLanguageScope extends InheritedNotifier<UiLanguagePreferences> {
  const UiLanguageScope({
    super.key,
    required UiLanguagePreferences preferences,
    required super.child,
  }) : super(notifier: preferences);
}

String uiText(BuildContext context, String english) {
  final scope = context.dependOnInheritedWidgetOfExactType<UiLanguageScope>();
  if (scope?.notifier?.value != 'ta') return english;
  final price = RegExp(r'^(Match · )?(\d+) coins$').firstMatch(english);
  if (price != null) {
    return '${price[1] == null ? '' : 'பொருத்தம் · '}${price[2]} நாணயங்கள்';
  }
  return tamilUi[english] ?? tamilBirthStar(english) ?? english;
}

class UiText extends StatelessWidget {
  const UiText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Text(
    uiText(context, text),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
  );
}

// Incremental catalogue. Missing strings stay visible in English; this is not
// a claim of complete localisation until all screens and dialogs are covered.
const tamilUi = <String, String>{
  'Choose someone to talk to.': 'பேச ஒரு வழிகாட்டியைத் தேர்ந்தெடுங்கள்.',
  'Start chat': 'உரையாடலைத் தொடங்குங்கள்',
  'Could not end chat. Please try again.': 'உரையாடலை முடிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'End chat': 'உரையாடலை முடிக்கவும்',
  'Use End chat to finish your conversation.':
      'உரையாடலை முடிக்க மேலே உள்ள முடிக்கும் பொத்தானைப் பயன்படுத்துங்கள்.',

  'Birth Chart': 'ஜாதகம்',
  'Your Jathagam': 'பிறப்பு விவரங்கள்',
  'Whose Birth Chart?': 'யாருடைய ஜாதகம்?',
  'Change Birth Chart': 'ஜாதகத்தை மாற்றவும்',
  'My profile': 'என் சுயவிவரம்',
  'Choose avatar': 'உருவத்தைத் தேர்ந்தெடுக்கவும்',
  'Choose your avatar': 'உங்கள் உருவத்தைத் தேர்ந்தெடுக்கவும்',
  'Find your own celestial style.': 'உங்களுக்கான ஜோதிட உருவம்.',
  'Use this avatar': 'இந்த உருவத்தைப் பயன்படுத்து',
  'My Rasi': 'என் ராசி',
  'Starlight': 'நட்சத்திர ஒளி',
  'Orbit': 'கோள்களின் பாதை',
  'Constellation': 'நட்சத்திரக் கூட்டம்',
  'Could not save avatar. Please retry.':
      'உருவத்தைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'Updates': 'புதுப்பிப்புகள்',
  'Offers': 'சலுகைகள்',
  'Tips': 'குறிப்புகள்',
  'No updates yet': 'புதுப்பிப்புகள் இல்லை',
  'No offers yet': 'சலுகைகள் இல்லை',
  'No tips yet': 'குறிப்புகள் இல்லை',
  'Continue chat': 'உரையாடலைத் தொடர்க',
  'Choose a guide. Start with one question.':
      'ஒரு வழிகாட்டியைத் தேர்ந்தெடுத்து உங்கள் கேள்வியைக் கேளுங்கள்.',
  'Choose guide →': 'வழிகாட்டியைத் தேர்ந்தெடுக்கவும் →',
  'Chat': 'பேசுங்கள்',
  'Matching': 'பொருத்தம்',
  'Meera': 'மீரா',
  'Janaki': 'ஜானகி',
  'Harini': 'ஹரிணி',
  'Revathi': 'ரேவதி',
  'Kavya': 'காவ்யா',
  'Aravind': 'அரவிந்த்',
  'Aditya': 'ஆதித்யா',
  'Karthik': 'கார்த்திக்',
  'Lakshmi': 'லட்சுமி',
  'Dating, new relationships and communication.':
      'காதல், புதிய உறவுகள் மற்றும் உரையாடல்.',
  'Mixed signals, trust concerns and healthy boundaries.':
      'உறவின் குழப்பங்கள், நம்பிக்கை மற்றும் ஆரோக்கியமான எல்லைகள்.',
  'Marriage, compatibility and commitment.':
      'திருமணம், பொருத்தம் மற்றும் உறுதிப்பாடு.',
  'Sign out?': 'வெளியேற வேண்டுமா?',
  'Are you sure you want to sign out?':
      'உங்கள் கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?',
  'Submit': 'சமர்ப்பிக்கவும்',
  'Skip': 'தவிர்க்கவும்',
  'Rate': 'மதிப்பிடுங்கள்',

  "Adithya": "ஆதித்யா",
  "Raghavan": "ராகவன்",
  "Commitment, family acceptance and married life.":
      "உறுதிப்பாடு, குடும்பத்தின் சம்மதம் மற்றும் திருமண வாழ்க்கை.",
  "Learning, exams, college and higher studies.":
      "கற்றல், தேர்வுகள், கல்லூரி மற்றும் உயர் கல்வி.",
  "Hobbies, creativity and personal interests.":
      "பொழுதுபோக்கு, படைப்பாற்றல் மற்றும் தனிப்பட்ட ஆர்வங்கள்.",
  "Jobs, promotions and career changes.":
      "வேலை, பதவி உயர்வு மற்றும் வேலை மாற்றங்கள்.",
  "Business direction and partnerships.": "தொழில் வளர்ச்சி மற்றும் கூட்டாண்மை.",
  "Family relationships, parenting and responsibilities.":
      "குடும்ப உறவுகள், குழந்தை வளர்ப்பு மற்றும் பொறுப்புகள்.",
  "Personal growth, confidence and life direction.":
      "தனிப்பட்ட வளர்ச்சி, தன்னம்பிக்கை மற்றும் வாழ்க்கைப் பாதை.",
  'Made for you.': 'உங்களுக்காக.',
  'Start with your birth details.': 'உங்கள் பிறந்த விவரங்களுடன் தொடங்குங்கள்.',
  'Birth date': 'பிறந்த தேதி',
  'Birth time': 'பிறந்த நேரம்',
  'Typing…': 'தட்டச்சு செய்கிறார்…',
  'Not known': 'தெரியாது',
  'Search your town or city': 'உங்கள் ஊர் அல்லது நகரத்தைத் தேடுங்கள்',
  'Continue to Jyotara': 'ஜோதராவில் தொடரவும்',
  'You can edit these details later in Profile.':
      'இந்த விவரங்களைப் பின்னர் சுயவிவரத்தில் மாற்றலாம்.',
  'Privacy & data use': 'தனியுரிமை மற்றும் தரவுப் பயன்பாடு',
  'More options': 'மேலும் தேர்வுகள்',
  'Full name': 'முழுப் பெயர்',
  'Please enter a valid name.': 'சரியான பெயரை உள்ளிடவும்.',
  'Town or city': 'ஊர் அல்லது நகரம்',
  'For example: Erode': 'எடுத்துக்காட்டு: ஈரோடு',
  'Clear search': 'தேடலை அழிக்கவும்',
  'Clear birthplace': 'பிறந்த இடத்தை அழிக்கவும்',
  'Type at least 3 characters.': 'குறைந்தது 3 எழுத்துகளை உள்ளிடவும்.',
  'Location search unavailable. Please retry.':
      'இடத் தேடல் கிடைக்கவில்லை. மீண்டும் முயலவும்.',
  'Birth time unknown · General guidance only':
      'பிறந்த நேரம் தெரியாது · பொதுவான வழிகாட்டல் மட்டும்',
  'Edit birth details': 'பிறந்த விவரங்களைத் திருத்தவும்',
  'Update your birth details to refresh your chart.':
      'ஜாதகத்தைப் புதுப்பிக்க பிறந்த விவரங்களைத் திருத்தவும்.',
  'General guidance only. You can add your birth time later.':
      'பொதுவான வழிகாட்டல் மட்டும். பிறந்த நேரத்தைப் பின்னர் சேர்க்கலாம்.',
  'Add birth time': 'பிறந்த நேரத்தைச் சேர்க்கவும்',
  'Enter full name': 'முழுப் பெயரை உள்ளிடவும்',
  'Enter your full name.': 'உங்கள் முழுப் பெயரை உள்ளிடவும்.',
  'Preferred chatting language': 'விருப்பமான உரையாடல் மொழி',
  'Relationship status (optional)': 'உறவு நிலை (விருப்பம்)',
  'Profession (optional)': 'தொழில் (விருப்பம்)',
  'Not specified': 'குறிப்பிடவில்லை',
  'Single': 'தனியாக உள்ளேன்',
  'In a relationship': 'காதல் உறவில் உள்ளேன்',
  'Married': 'திருமணமானவர்',
  'Separated': 'பிரிந்து வாழ்கிறேன்',
  'Divorced': 'விவாகரத்தானவர்',
  'Widowed': 'துணையை இழந்தவர்',
  'Student': 'மாணவர்',
  'Employed': 'பணியில் உள்ளேன்',
  'Self-employed': 'சுயதொழில்',
  'Business owner': 'தொழில் உரிமையாளர்',
  'Homemaker': 'இல்லத்தரசர் / இல்லத்தரசி',
  'Looking for work': 'வேலை தேடுகிறேன்',
  'Retired': 'ஓய்வு பெற்றவர்',
  'Other': 'மற்றவை',
  "Love & Marriage": "காதல் & திருமணம்",
  "Education & Hobbies": "கல்வி & ஆர்வங்கள்",
  "Career & Business": "வேலை & தொழில்",
  "Family & Personal Life": "குடும்பம் & தனிப்பட்ட வாழ்க்கை",
  "Your Love Life": "உங்கள் காதல் வாழ்க்கை",
  "Love & Trust": "காதல் & நம்பிக்கை",
  "Your Marriage": "உங்கள் திருமணம்",
  "Love to Marriage": "காதல் முதல் திருமணம் வரை",
  "Your Future": "உங்கள் எதிர்காலம்",
  "Your Passions": "உங்கள் ஆர்வங்கள்",
  "Your Career": "உங்கள் வேலை",
  "Your Business": "உங்கள் தொழில்",
  "Your Family": "உங்கள் குடும்பம்",
  "Your Journey": "உங்கள் பயணம்",
  "Previous guide chats": "முந்தைய வழிகாட்டி உரையாடல்கள்",
  'Saved result · No additional coins used':
      'சேமித்த முடிவு · கூடுதல் நாணயங்கள் கழியவில்லை',
  'Could not save changes. Please retry.':
      'மாற்றங்களைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'Relationship Matching': 'உறவுப் பொருத்தம்',
  'What matches': 'எவை பொருந்துகின்றன',
  'Your Vedic guides': 'உங்கள் வேத வழிகாட்டிகள்',
  'Relationships': 'உறவுகள்',
  'SAME STARS. A BRIGHTER YOU.': 'அதே நட்சத்திரங்கள். புதிய ஒளியில் நீங்கள்.',
  'Personal growth': 'தனிப்பட்ட வளர்ச்சி',
  'What’s on your mind today?': 'இன்று உங்கள் மனதில் என்ன?',
  'Ask your guide': 'உங்கள் வழிகாட்டியிடம் கேளுங்கள்',
  'Good morning,': 'காலை வணக்கம்,',
  'Good afternoon,': 'மதிய வணக்கம்,',
  'Good evening,': 'மாலை வணக்கம்,',
  'Your profile': 'உங்கள் விவரங்கள்',
  'YOUR BIRTH CHART': 'உங்கள் பிறப்பு ஜாதகம்',
  'A little clarity,\nfor your day.': 'உங்கள் நாளுக்கு\nஒரு சிறு தெளிவு.',
  'Ask your AI guide': 'உங்கள் AI வழிகாட்டியிடம் கேளுங்கள்',
  'Guidance in English, Tamil & Tanglish':
      'ஆங்கிலம், தமிழ், தங்கிலிஷில் வழிகாட்டல்',
  'Start a conversation': 'உரையாடலைத் தொடங்குங்கள்',
  'Notifications': 'அறிவிப்புகள்',
  'Notification settings': 'அறிவிப்பு அமைப்புகள்',
  'A quieter space for updates': 'உங்கள் அறிவிப்புகள் இங்கே',
  'Your Jyotara updates will appear here. Enable notifications in settings to receive them.': 'Jyotara அறிவிப்புகள் இங்கே தோன்றும். அவற்றைப் பெற அமைப்புகளில் அறிவிப்புகளை இயக்கவும்.',
  'Clear updates': 'அறிவிப்புகளை நீக்கு',

  'AI chat': 'AI உரையாடல்',
  'AI chat · Coming soon': 'AI உரையாடல் · விரைவில்',
  'Something thoughtful is on its way': 'புதிய வழிகாட்டுதல் விரைவில்',
  'AI chat is temporarily unavailable while we prepare paid access. Your saved conversations remain on this device.': 'கட்டண வசதியைத் தயார்செய்வதால் AI உரையாடல் தற்காலிகமாகக் கிடைக்காது. சேமித்த உரையாடல்கள் இந்தச் சாதனத்தில் இருக்கும்.',
  'Daily horoscopes, Free Birth Chart and Birth Chart Matching are still available.': 'தினசரி ராசிபலன், இலவச ஜாதகம் மற்றும் ஜாதகப் பொருத்தம் தொடர்ந்து கிடைக்கும்.',
  'Support: jyotara29@gmail.com': 'உதவி: jyotara29@gmail.com',
  'Notifications & app improvements': 'அறிவிப்புகள் மற்றும் செயலி மேம்பாடுகள்',
  'Optional services provided by Google Firebase. Birth details and chat text are not included in analytics events.': 'Google Firebase வழங்கும் விருப்பச் சேவைகள். பிறப்பு விவரங்களும் உரையாடல்களும் பயன்பாட்டுப் புள்ளிவிவரங்களில் சேர்க்கப்படாது.',
  'Meta measurement': 'Meta பயன்பாட்டு அளவீடு',
  'Allow Meta to measure app opens, successful sign-ins and completed readings. Device information is shared; birth details and chat text are excluded.': 'செயலி திறப்பு, வெற்றிகரமான உள்நுழைவு மற்றும் முடிந்த வாசிப்புகளை Meta அளவிட அனுமதிக்கவும். சாதனத் தகவல்கள் பகிரப்படும்; பிறப்பு விவரங்களும் உரையாடல்களும் சேர்க்கப்படாது.',
  'Optional services provided by Google Firebase, Singular and Meta. Birth details and chat text are not included in analytics events.': 'Google Firebase, Singular மற்றும் Meta வழங்கும் விருப்பச் சேவைகள். பிறப்பு விவரங்களும் உரையாடல்களும் பயன்பாட்டுப் புள்ளிவிவரங்களில் சேர்க்கப்படாது.',
  'Usage analytics': 'பயன்பாட்டுப் புள்ளிவிவரங்கள்',
  'Share app usage and device information to help improve Jyotara.':
      'Jyotara மேம்பட செயலியின் பயன்பாடு மற்றும் சாதனத் தகவல்களைப் பகிரவும்.',
  'Crash reports': 'செயலி செயலிழப்பு அறிக்கைகள்',
  'Share technical error and device reports to help fix crashes.': 'செயலிழப்புகளைச் சரிசெய்ய தொழில்நுட்பப் பிழை மற்றும் சாதன அறிக்கைகளைப் பகிரவும்.',
  'Chat: 40 coins per started minute. The next minute is charged only when you ask again. Waiting for an answer is not charged. Limited general guidance stays free.': 'உரையாடலின் ஒவ்வொரு தொடங்கிய நிமிடத்துக்கும் 40 நாணயங்கள். மீண்டும் கேள்வி கேட்டால் மட்டுமே அடுத்த நிமிடத்துக்குக் கட்டணம். பதிலுக்காகக் காத்திருக்கும் நேரத்துக்குக் கட்டணம் இல்லை. பொதுவான வழிகாட்டல் இலவசம்.',
  'App notifications': 'செயலி அறிவிப்புகள்',
  'Receive Jyotara updates. You can turn these off at any time.':
      'Jyotara அறிவிப்புகளைப் பெறவும். எப்போது வேண்டுமானாலும் நிறுத்தலாம்.',
  'Allow notifications in Android settings to enable updates.':
      'அறிவிப்புகளைப் பெற Android அமைப்புகளில் அனுமதி வழங்கவும்.',
  'Connecting app services. If this continues, restart the app.': 'செயலிச் சேவைகள் இணைக்கப்படுகின்றன. இது தொடர்ந்தால் செயலியை மீண்டும் திறக்கவும்.',
  'Could not save this setting. Please try again.':
      'இந்த அமைப்பைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',

  'Delete account': 'கணக்கை நீக்கு',
  'Delete account?': 'கணக்கை நீக்க வேண்டுமா?',
  'Delete phone account, saved profiles and chats':
      'தொலைபேசிக் கணக்கு, சேமித்த ஜாதகங்கள் மற்றும் உரையாடல்களை நீக்கவும்',
  'This removes your phone account and its saved profiles and chats from this device and our server. Minimal security records and backups remain temporarily. External service deletion may still be pending.': 'உங்கள் தொலைபேசிக் கணக்கு, சேமித்த ஜாதகங்கள் மற்றும் உரையாடல்கள் இந்தச் சாதனத்திலிருந்தும் எங்கள் சேவையகத்திலிருந்தும் நீக்கப்படும். குறைந்தபட்சப் பாதுகாப்புப் பதிவுகளும் காப்புப் பிரதிகளும் தற்காலிகமாக இருக்கும். வெளிச்சேவையில் உள்ள தரவை நீக்கும் பணி இன்னும் நிலுவையில் இருக்கலாம்.',
  'Payments not enabled': 'கட்டண வசதி செயல்படுத்தப்படவில்லை',
  'AI astrology guidance': 'செயற்கை நுண்ணறிவு ஜோதிட வழிகாட்டுதல்',
  'Daily limits apply to chart calculations and place searches. A failed calculation may still count toward its daily limit. Payments are not enabled; no money is deducted.': 'ஜாதகக் கணக்கீடுகளுக்கும் இடத் தேடல்களுக்கும் தினசரி வரம்புகள் உள்ளன. தோல்வியடைந்த கணக்கீடும் அந்த வரம்பில் சேரலாம். கட்டண வசதி செயல்படுத்தப்படவில்லை; பணம் பிடிக்கப்படாது.',
  'Jyotara offers AI astrology guidance based on traditional interpretations. Guides are automated, not human astrologers. Predictions are not guarantees. Do not use them as medical, legal or investment advice.': 'Jyotara பாரம்பரிய விளக்கங்களின் அடிப்படையில் செயற்கை நுண்ணறிவு ஜோதிட வழிகாட்டுதலை வழங்குகிறது. வழிகாட்டிகள் தானியங்கிகள்; மனித ஜோதிடர்கள் அல்ல. கணிப்புகள் உறுதியான முடிவுகள் அல்ல. அவற்றை மருத்துவ, சட்ட அல்லது முதலீட்டு ஆலோசனையாகப் பயன்படுத்த வேண்டாம்.',
  'Privacy policy': 'தனியுரிமைக் கொள்கை',
  'Account deletion help': 'கணக்கை நீக்க உதவி',
  'Open in your browser': 'உலாவியில் திறக்கவும்',
  'Report answer': 'பதிலைப் புகாரளிக்கவும்',
  'Choose a reason to send this answer and the guide name to the Jyotara team for review. No other messages or separate birth-profile fields are attached.': 'இந்தப் பதிலையும் வழிகாட்டியின் பெயரையும் ஜோதாரா குழுவின் ஆய்வுக்கு அனுப்ப ஒரு காரணத்தைத் தேர்ந்தெடுக்கவும். மற்ற செய்திகள் அல்லது பிறப்பு விவரங்கள் தனியாக இணைக்கப்படாது.',
  'Harmful or unsafe': 'தீங்கு விளைவிக்கும் அல்லது பாதுகாப்பற்ற பதில்',
  'Sexual content': 'பாலியல் உள்ளடக்கம்',
  'Hateful or abusive': 'வெறுப்பு அல்லது அவமதிப்பு',
  'Misleading answer': 'தவறாக வழிநடத்தும் பதில்',
  'Privacy concern': 'தனியுரிமை தொடர்பான சிக்கல்',
  'Other concern': 'வேறு சிக்கல்',
  'Report sent to the Jyotara team. Thank you.':
      'புகார் ஜோதாரா குழுவுக்கு அனுப்பப்பட்டது. நன்றி.',
  'Report could not be confirmed. Please try again.': 'புகார் அனுப்பப்பட்டதை உறுதிப்படுத்த முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'Wallet · ₹0  +': 'பணப்பை · ₹0  +',
  'Unable to connect. Check your internet connection, then tap Retry.': 'இணைக்க முடியவில்லை. இணைய இணைப்பைச் சரிபார்த்து, மீண்டும் முயற்சிக்கவும்.',
  'The reading is taking longer than expected. Please try again shortly.': 'பலன் வருவதற்குச் சற்று தாமதமாகிறது. சிறிது நேரத்தில் மீண்டும் முயற்சிக்கவும்.',
  'The reading could not be loaded. Please try again shortly.':
      'பலனை ஏற்ற முடியவில்லை. சிறிது நேரத்தில் மீண்டும் முயற்சிக்கவும்.',
  'Birth details · India (IST)': 'பிறப்பு விவரங்கள் · இந்திய நேரம்',
  'Name or alias': 'பெயர் அல்லது புனைப்பெயர்',
  'Birthplace': 'பிறந்த இடம்',
  'Choose a search result.': 'தேடல் முடிவிலிருந்து தேர்ந்தெடுக்கவும்.',
  'I am 13+ and agree to use my birth details for readings.': 'எனக்கு 13 வயதுக்கு மேல்; பலன்களுக்கு என் பிறப்பு விவரங்களைப் பயன்படுத்தச் சம்மதிக்கிறேன்.',
  'Privacy details': 'தனியுரிமை விவரங்கள்',
  'Readings offer guidance, not guaranteed outcomes.':
      'பலன்கள் வழிகாட்டல் மட்டுமே; உறுதியான முடிவுகள் அல்ல.',
  'Using noon as an estimate. Rasi may vary; Lagnam and Dasa are unavailable.': 'மதிய நேரம் தோராயமாகப் பயன்படுத்தப்படும். ராசி மாறலாம்; லக்னம், தசா கிடைக்காது.',
  'Location data: GeoNames (CC BY 4.0) · geonames.org':
      'இடத் தகவல்: GeoNames (CC BY 4.0) · geonames.org',
  "Your birth details, questions and recent chat context are processed by astrology and language services. External astrology conversation deletion may still be pending after local and server deletion. Manage your saved profile from the Chart tab. Research sharing is optional.": "உங்கள் பிறந்த விவரங்கள், கேள்விகள் மற்றும் சமீபத்திய உரையாடல்கள் ஜோதிட மற்றும் மொழிச் சேவைகளில் செயலாக்கப்படுகின்றன. சாதனம் மற்றும் எங்கள் சேவையகத்தில் நீக்கிய பின்னரும் வெளிச் சேவையின் உரையாடல் நீக்கம் நிலுவையில் இருக்கலாம். ஜாதகம் பகுதியில் விவரங்களை நிர்வகிக்கலாம். ஆய்வுப் பகிர்வு உங்கள் விருப்பம்.",
  'Ashta Kuta': 'அஷ்டகூடப் பொருத்தம்',
  'If a birth time is unknown, we use noon for a provisional comparison. The score may change with the actual time.': 'பிறந்த நேரம் தெரியாவிட்டால் நண்பகல் நேரத்தில் உத்தேசமாக ஒப்பிடுவோம். உண்மையான நேரத்தால் மதிப்பெண் மாறலாம்.',
  'The daily reading is unavailable right now. Please try again later.': 'தினசரிப் பலன் இப்போது கிடைக்கவில்லை. சிறிது நேரத்தில் மீண்டும் முயலவும்.',
  'Matching is unavailable right now. No result has been created.':
      'பொருத்தம் இப்போது கிடைக்கவில்லை. முடிவு உருவாக்கப்படவில்லை.',

  "Daily\nHoroscope": "தினசரி\nராசிபலன்",
  "Free\nKundli": "இலவச\nஜாதகம்",
  "Birth Chart\nMatching": "ஜாதகப்\nபொருத்தம்",
  "Free Birth Chart": "இலவச ஜாதகம்",
  'Open birth chart': 'சேமித்த ஜாதகங்கள்',
  'New Matching': 'புதிய பொருத்தம்',
  'No saved birth charts yet. Use New Matching to enter birth details.': 'சேமித்த ஜாதகங்கள் இல்லை. புதிய பொருத்தத்தில் பிறப்பு விவரங்களைச் சேர்க்கவும்.',
  'No matching names found.': 'இந்தப் பெயரில் ஜாதகம் இல்லை.',
  'Choose two different profiles.':
      'இரண்டு வெவ்வேறு ஜாதகங்களைத் தேர்ந்தெடுக்கவும்.',
  'Compatibility score': 'பொருத்த மதிப்பெண்',
  'Score breakdown': 'பொருத்த விவரங்கள்',
  'Unknown birth time': 'பிறந்த நேரம் தெரியவில்லை',
  'Mangal Dosha': 'செவ்வாய் தோஷம்',
  'Present': 'உள்ளது',
  'Not present': 'இல்லை',
  'Exception reported': 'விதிவிலக்கு உள்ளது',
  "Birth Chart Matching": "ஜாதகப் பொருத்தம்",
  "A little guidance for your day": "உங்கள் நாளுக்கான சிறு வழிகாட்டல்",
  "General zodiac readings for all 12 signs. These are not personal birth-chart predictions.": "12 ராசிகளுக்குமான பொதுப் பலன்கள். இவை தனிப்பட்ட பிறப்பு ஜாதகப் பலன்கள் அல்ல.",
  "General": "பொதுப் பலன்",
  "Full reading": "முழுப் பலன்",
  "Money · everyday reminder": "பணம் · அன்றாட நினைவூட்டல்",
  "Health · everyday reminder": "உடல்நலம் · அன்றாட நினைவூட்டல்",
  "Check your available budget before spending. Give yourself time to compare options before a purchase.": "செலவு செய்வதற்கு முன் உங்கள் கையிருப்பைப் பாருங்கள். வாங்குவதற்கு முன் தேர்வுகளை ஒப்பிட நேரம் எடுத்துக்கொள்ளுங்கள்.",
  "Make room for rest, regular meals and comfortable movement today. A horoscope cannot assess your health.": "இன்று ஓய்வு, நேரத்துக்கு உணவு, உடலுக்கு ஏற்ற இயக்கம் ஆகியவற்றுக்கு இடமளியுங்கள். ராசிபலனால் உடல்நிலையை மதிப்பிட முடியாது.",
  "These daily readings are traditional astrology, not medical assessments. Money is an everyday reminder, not a date-specific forecast.": "இந்த தினசரிப் பலன்கள் பாரம்பரிய ஜோதிட விளக்கங்கள்; மருத்துவ மதிப்பீடுகள் அல்ல. பணம் குறித்த பகுதி அன்றாட நினைவூட்டல்; குறிப்பிட்ட நாளின் கணிப்பு அல்ல.",
  "Charts for the people you know": "உங்களுக்குத் தெரிந்தவர்களின் ஜாதகங்கள்",
  "Save up to 10 separate birth charts with permission. Your own chat profile stays separate. Up to 10 new chart sessions per tester per day.": "அனுமதியுடன் 10 ஜாதகங்கள் வரை சேமிக்கலாம். உங்கள் உரையாடல் சுயவிவரம் தனியாக இருக்கும். ஒரு சோதனைப் பயனர் நாளொன்றுக்கு 10 புதிய ஜாதகங்கள் வரை உருவாக்கலாம்.",
  "Search birth chart by name": "பெயரால் ஜாதகத்தைத் தேடுங்கள்",
  "Retry loading birth charts": "ஜாதகங்களை மீண்டும் ஏற்றுங்கள்",
  "Your saved birth charts will appear here.":
      "சேமித்த ஜாதகங்கள் இங்கே தோன்றும்.",
  "Unfinished Birth Chart": "முடிக்கப்படாத ஜாதகம்",
  "Birthplace not saved": "பிறந்த இடம் சேமிக்கப்படவில்லை",
  "Calculated from the saved birth details.":
      "சேமித்த பிறந்த விவரங்களிலிருந்து கணக்கிடப்பட்டது.",
  "Birth time is unknown. Time-sensitive chart details are limited.":
      "பிறந்த நேரம் தெரியவில்லை. நேரத்தைச் சார்ந்த ஜாதக விவரங்கள் வரம்புடையவை.",
  "Edit birth chart": "ஜாதகத்தைத் திருத்தவும்",
  "Delete birth chart": "ஜாதகத்தை நீக்கவும்",
  "Create New Birth Chart": "புதிய ஜாதகம் உருவாக்கவும்",
  "Delete this birth chart?": "இந்த ஜாதகத்தை நீக்க வேண்டுமா?",
  "This removes its saved chart from this device and the server.":
      "இந்தச் சாதனத்திலும் சேவையகத்திலும் சேமித்த ஜாதகம் நீக்கப்படும்.",
  "Saved birth charts could not be opened. Please retry.":
      "சேமித்த ஜாதகங்களைத் திறக்க முடியவில்லை. மீண்டும் முயலவும்.",
  "Could not open saved birth charts.":
      "சேமித்த ஜாதகங்களைத் திறக்க முடியவில்லை.",
  "Compare two birth charts": "இருவரின் ஜாதகங்களை ஒப்பிடுங்கள்",
  "Traditional Ashta Kuta matching · 36 points. This calculation uses the male and female roles of that system; it does not measure love or guarantee a marriage outcome.": "பாரம்பரிய அஷ்டகூடப் பொருத்தம் · 36 புள்ளிகள். இந்த முறையின் ஆண், பெண் அடிப்படையில் கணக்கிடப்படுகிறது. இது காதலை அளவிடுவதோ திருமண முடிவை உறுதிப்படுத்துவதோ அல்ல.",
  "Boy’s birth chart": "ஆணின் ஜாதகம்",
  "Girl’s birth chart": "பெண்ணின் ஜாதகம்",
  "Boy": "ஆண்",
  "Girl": "பெண்",
  "Saved profile": "சேமித்த சுயவிவரம்",
  "Boy: details used for matching": "ஆண்: பொருத்தத்திற்கான விவரங்கள்",
  "Girl: details used for matching": "பெண்: பொருத்தத்திற்கான விவரங்கள்",
  "Enter birth details": "பிறந்த விவரங்களை உள்ளிடுங்கள்",
  "Create or edit birth charts": "ஜாதகங்களை உருவாக்கவும் அல்லது திருத்தவும்",
  "Permission confirmed for both people.":
      "இருவரின் அனுமதியும் உறுதிசெய்யப்பட்டது.",
  "I confirm both people agree to this comparison.":
      "இந்த ஒப்பீட்டிற்கு இருவரும் சம்மதிப்பதை உறுதிசெய்கிறேன்.",
  "Comparing…": "ஒப்பிடப்படுகிறது…",
  "Match Horoscope": "ஜாதகப் பொருத்தம் பார்க்கவும்",
  "Matching result": "பொருத்த முடிவு",
  "Provisional comparison": "உத்தேசப் பொருத்தம்",
  "Done": "முடிந்தது",
  "No birth details entered yet.": "பிறந்த விவரங்கள் இன்னும் உள்ளிடப்படவில்லை.",
  "Birth time unknown — provisional comparison":
      "பிறந்த நேரம் தெரியாது — உத்தேச ஒப்பீடு",
  "confirmed birth time": "உறுதியான பிறந்த நேரம்",
  "Check matching details": "பொருத்த விவரங்களைச் சரிபார்க்கவும்",
  "Enter birth details for both people, or choose their saved birth charts.": "இருவரின் பிறந்த விவரங்களை உள்ளிடுங்கள் அல்லது சேமித்த ஜாதகங்களைத் தேர்ந்தெடுங்கள்.",
  "Confirm that both people agreed to this comparison.":
      "இந்த ஒப்பீட்டிற்கு இருவரும் சம்மதித்ததை உறுதிசெய்யுங்கள்.",
  "This saved chart has no usable birth details. Please enter the birth details again.": "இந்த ஜாதகத்தில் பயன்படுத்தக்கூடிய பிறந்த விவரங்கள் இல்லை. மீண்டும் உள்ளிடுங்கள்.",

  'Welcome, tester': 'சோதனைப் பயனரே, வரவேற்கிறோம்',
  'This build is available to invited testers. Enter the access code shared with you.': 'அழைக்கப்பட்ட சோதனைப் பயனர்களுக்கான பதிப்பு இது. உங்களுடன் பகிரப்பட்ட அணுகல் குறியீட்டை உள்ளிடவும்.',
  'Tester access code': 'சோதனை அணுகல் குறியீடு',
  'Checking access…': 'அணுகல் சரிபார்க்கப்படுகிறது…',
  'Enter the complete tester access code.':
      'முழுமையான சோதனை அணுகல் குறியீட்டை உள்ளிடவும்.',
  'The tester code is invalid or expired.':
      'சோதனை குறியீடு செல்லுபடியாகவில்லை அல்லது காலாவதியாகிவிட்டது.',
  'Unable to verify access. Please try again.':
      'அணுகலைச் சரிபார்க்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'Unable to verify or save access. Check your connection and try again.': 'அணுகலைச் சரிபார்க்கவோ சேமிக்கவோ முடியவில்லை. இணைய இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
  'Tester access could not be restored. Enter your code again.':
      'சோதனை அணுகலை மீட்டெடுக்க முடியவில்லை. குறியீட்டை மீண்டும் உள்ளிடவும்.',
  'Usage limits are enforced by the test service. Failed or uncertain requests may still count. Ask the test coordinator for your assigned limits. Payments are not enabled in this build.': 'பயன்பாட்டு வரம்புகளைச் சோதனைச் சேவை கட்டுப்படுத்துகிறது. தோல்வியடைந்த அல்லது உறுதிப்படுத்தப்படாத கோரிக்கைகளும் கணக்கில் சேரலாம். உங்கள் வரம்புகளைச் சோதனை ஒருங்கிணைப்பாளரிடம் கேளுங்கள். இந்தப் பதிப்பில் கட்டண வசதி இல்லை.',

  'Continue': 'தொடரவும்',
  'Select your gender': 'உங்கள் பாலினத்தைத் தேர்ந்தெடுக்கவும்',
  'Choose what you want to share. You can change this later.':
      'நீங்கள் பகிர விரும்புவதைத் தேர்ந்தெடுக்கவும். பின்னர் இதை மாற்றலாம்.',
  'Male': 'ஆண்',
  'Female': 'பெண்',
  'Non-binary': 'ஆண் அல்லது பெண் என அடையாளப்படுத்தாதவர்',
  'Prefer not to say': 'பகிர விரும்பவில்லை',
  'Gender': 'பாலினம்',
  'Not selected': 'தேர்ந்தெடுக்கப்படவில்லை',
  'Saved with your profile. Your selected gender is used when requesting a detailed astrology report.': 'உங்கள் விவரங்களுடன் சேமிக்கப்படும். விரிவான ஜாதக அறிக்கையைக் கோரும்போது நீங்கள் தேர்ந்தெடுத்த பாலினம் பயன்படுத்தப்படும்.',

  'These periods belong to the saved calculation date. New chat answers check the current period separately.': 'இவை சேமித்த கணக்கீட்டுத் தேதிக்கான தசை–புக்திகள். புதிய உரையாடல் பதில்களுக்கு நடப்புக் காலம் தனியாகச் சரிபார்க்கப்படும்.',
  'Navamsa (D9)': 'நவாம்சம் (D9)',
  'Rasi chart · South Indian layout': 'ராசிக் கட்டம் · தென்னிந்திய முறை',
  'Navamsa chart · South Indian layout': 'நவாம்சக் கட்டம் · தென்னிந்திய முறை',
  'Navamsa is withheld because exact birth time is unknown.':
      'துல்லியமான பிறந்த நேரம் தெரியாததால் நவாம்சம் காட்டப்படவில்லை.',
  'Navamsa is unavailable in this saved chart. No extra calculation has been requested automatically.': 'இந்தச் சேமித்த ஜாதகத்தில் நவாம்சம் கிடைக்கவில்லை. கூடுதல் கணக்கீடு தானாகக் கோரப்படவில்லை.',
  'Planet positions only; the Navamsa ascendant is not displayed. This is separate from your Rasi chart.': 'கிரக நிலைகள் மட்டும்; நவாம்ச லக்னம் காட்டப்படவில்லை. இது உங்கள் ராசிக் கட்டத்திலிருந்து வேறுபட்டது.',
  'Mesha · Aries': 'மேஷம்',
  'Vrishabha · Taurus': 'ரிஷபம்',
  'Mithuna · Gemini': 'மிதுனம்',
  'Karka · Cancer': 'கடகம்',
  'Simha · Leo': 'சிம்மம்',
  'Kanya · Virgo': 'கன்னி',
  'Tula · Libra': 'துலாம்',
  'Vrischika · Scorpio': 'விருச்சிகம்',
  'Dhanu · Sagittarius': 'தனுசு',
  'Makara · Capricorn': 'மகரம்',
  'Kumbha · Aquarius': 'கும்பம்',
  'Meena · Pisces': 'மீனம்',
  'Daily Horoscope': 'தினசரி ராசிபலன்',
  'Yesterday': 'நேற்று',
  'Today': 'இன்று',
  'Tomorrow': 'நாளை',
  'Mesha': 'மேஷம்',
  'Vrishabha': 'ரிஷபம்',
  'Mithuna': 'மிதுனம்',
  'Karka': 'கடகம்',
  'Simha': 'சிம்மம்',
  'Kanya': 'கன்னி',
  'Tula': 'துலாம்',
  'Vrischika': 'விருச்சிகம்',
  'Dhanu': 'தனுசு',
  'Makara': 'மகரம்',
  'Kumbha': 'கும்பம்',
  'Meena': 'மீனம்',
  'Check the device clock before renewing chat access.': 'உரையாடல் அணுகலைப் புதுப்பிக்கும் முன் சாதனத்தின் தேதி மற்றும் நேரத்தைச் சரிபார்க்கவும்.',
  'Your profile changed while chat access was being renewed.':
      'உரையாடல் அணுகல் புதுப்பிக்கப்படும்போது பிறப்பு விவரங்கள் மாற்றப்பட்டன.',
  'Renewed access could not be saved. The question was not sent; please retry.': 'புதுப்பித்த அணுகலைச் சேமிக்க முடியவில்லை. கேள்வி அனுப்பப்படவில்லை; மீண்டும் முயலுங்கள்.',
  'The renewed chat access could not be verified. Your saved chart was not replaced.': 'புதுப்பித்த உரையாடல் அணுகலைச் சரிபார்க்க முடியவில்லை. சேமித்த ஜாதகம் மாற்றப்படவில்லை.',
  'This saved chart cannot be renewed. Its protected renewal window may have expired.': 'இந்தச் சேமித்த ஜாதகத்தின் உரையாடல் அணுகலைப் புதுப்பிக்க முடியவில்லை. புதுப்பிக்க அனுமதிக்கப்பட்ட காலம் முடிந்திருக்கலாம்.',
  'This chart session was deleted.': 'இந்த ஜாதக அமர்வு நீக்கப்பட்டது.',
  'Deletion was requested but not completed on this device. Retry deletion before continuing.': 'தரவு நீக்கம் கோரப்பட்டது; இந்தச் சாதனத்தில் இன்னும் முடியவில்லை. தொடர்வதற்கு முன் நீக்கத்தை மீண்டும் முயலுங்கள்.',
  'Finish or retry deletion before asking another question.': 'அடுத்த கேள்விக்கு முன் தரவு நீக்கத்தை முடிக்கவும் அல்லது மீண்டும் முயலவும்.',
  'Delete server and device data': 'சர்வர் மற்றும் சாதனத் தரவை நீக்கு',
  'Deleting data…': 'தரவு நீக்கப்படுகிறது…',
  'Deletion did not finish. Check the status above and retry.': 'தரவு நீக்கம் முடியவில்லை. மேலே உள்ள நிலையைப் பார்த்து மீண்டும் முயலுங்கள்.',
  'Server deletion was not confirmed. Your saved profile is kept so you can retry. No deletion success is claimed.': 'சர்வரில் தரவு நீக்கப்பட்டது உறுதியாகவில்லை. மீண்டும் முயல உங்கள் சேமித்த விவரங்கள் வைக்கப்பட்டுள்ளன. தரவு நீக்கப்பட்டதாகக் கருத வேண்டாம்.',
  'Delete this session’s server chart cache, research questions and answer copies, then clear this device’s profile and history. Minimal usage and revocation records remain. Internet is required; if deletion fails, keep this app installed and retry.': 'இந்த அமர்வின் சர்வரில் உள்ள ஜாதகச் சேமிப்பு, ஆய்வுக் கேள்விகள், பதில் நகல்களை நீக்கி, பின்னர் இந்தச் சாதனத்தின் பிறப்பு விவரங்களையும் வரலாற்றையும் நீக்கும். குறைந்தபட்ச பயன்பாடு மற்றும் அணுகல் ரத்து பதிவுகள் இருக்கும். இணையம் தேவை; நீக்கம் தோல்வியுற்றால் செயலியை அகற்றாமல் மீண்டும் முயலுங்கள்.',
  'Your AI Vedic Guides': 'உங்கள் AI வேத வழிகாட்டிகள்',
  'View all': 'அனைத்தையும் காண்க',
  'Daily tools': 'தினசரி வசதிகள்',
  'Daily Panchangam': 'தினசரி பஞ்சாங்கம்',
  'Daily timings are not connected on this screen yet. Your birth chart is not today’s Panchangam. No daily timings are being shown.': 'இந்தத் திரையில் தினசரி நேரங்கள் இன்னும் இணைக்கப்படவில்லை. உங்கள் பிறப்பு ஜாதகம் இன்றைய பஞ்சாங்கம் அல்ல. இங்கு தினசரி நேரங்கள் காட்டப்படவில்லை.',
  'YOUR PERSONAL CONTEXT': 'உங்கள் பிறப்பு விவரங்கள்',
  'Start with your\nVedic birth chart.':
      'உங்கள் வேத ஜாதகத்துடன்\nதொடங்குங்கள்.',
  'Add your date, time and birthplace. Every guide uses this profile.': 'பிறந்த தேதி, நேரம், ஊரைச் சேர்க்கவும். அனைத்து வழிகாட்டிகளும் இந்த விவரங்களையே பயன்படுத்துவார்கள்.',
  'Explore your birth chart and planetary positions.':
      'உங்கள் பிறப்பு ஜாதகத்தையும் கிரக நிலைகளையும் பார்க்கலாம்.',
  'Ask in your natural language': 'உங்களுக்கு இயல்பான மொழியில் கேளுங்கள்',
  'Choose English or Tamil menus in Account. Chat in English, Tamil or Tanglish; set your reply language separately.': 'கணக்குப் பகுதியில் ஆங்கிலம் அல்லது தமிழ் மெனுவைத் தேர்ந்தெடுக்கவும். ஆங்கிலம், தமிழ் அல்லது தங்கிலீஷில் கேளுங்கள்; பதில் மொழியைத் தனியாகத் தேர்ந்தெடுக்கலாம்.',
  'This test app supports personal birth profiles for people aged 13 or older.': 'இந்தச் சோதனைச் செயலியில் 13 வயது நிறைவடைந்தவர்களின் சொந்த பிறப்பு விவரங்களை மட்டுமே பயன்படுத்தலாம்.',
  'For same-day retry recovery, the server also keeps an encrypted chart response for up to 23 hours, separately from research consent. Expired copies are removed when chart requests arrive; scheduled deletion is not yet available.': 'அதே நாளில் மீண்டும் முயற்சிக்கும்போது ஜாதகத்தை மீட்க, அதன் பதில் சேவையகத்தில் அதிகபட்சம் 23 மணி நேரம் மறையாக்கம் செய்து வைக்கப்படும். இது ஆய்வுச் சம்மதத்திலிருந்து தனியானது. காலாவதியான பிரதிகள் அடுத்த ஜாதகக் கோரிக்கைகள் வரும்போது நீக்கப்படும்; குறிப்பிட்ட நேரத்தில் தானாக நீக்கும் வசதி இன்னும் இல்லை.',
  'Recovered the earlier chart without a new calculation. The calculation time below is the original time.': 'புதிதாகக் கணக்கிடாமல் முந்தைய ஜாதகம் மீட்கப்பட்டது. கீழே காட்டப்படுவது முதலில் கணக்கிட்ட நேரம்.',
  'The test backend allows three question requests per session and one chart attempt per session per day, within a shared daily cap. Uncertain or failed attempts may still count to prevent duplicate charges. Payments are not enabled in this build.': 'இந்தச் சோதனைப் பதிப்பில் ஒரு அமர்வுக்கு மூன்று கேள்விக் கோரிக்கைகளும், ஒரு நாளில் ஒரு அமர்வுக்கு ஒரு ஜாதக முயற்சியும் அனுமதிக்கப்படும். அனைவருக்கும் பொதுவான தினசரி வரம்பும் உள்ளது. மீண்டும் கட்டணம் ஏற்படாமல் இருக்க, முடிவு உறுதியாகத் தெரியாத அல்லது தோல்வியடைந்த முயற்சிகளும் கணக்கில் சேரலாம். இந்தப் பதிப்பில் கட்டணம் செலுத்தும் வசதி இல்லை.',
  'Your profile and conversations are saved in encrypted device storage. Reopen a guide to see its history. Changing or deleting the profile removes the previous history. This is not cloud backup or cross-device account recovery. Check the Chart tab for storage errors.': 'உங்கள் பிறப்பு விவரங்களும் உரையாடல்களும் இந்தச் சாதனத்தில் மறையாக்கம் செய்து சேமிக்கப்படும். பழைய உரையாடலைப் பார்க்க அதே வழிகாட்டியை மீண்டும் திறக்கவும். பிறப்பு விவரங்களை மாற்றினாலோ நீக்கினாலோ பழைய வரலாறு நீங்கும். இது மேகக் காப்புப்பிரதி அல்ல; வேறு சாதனத்தில் கணக்கை மீட்டெடுக்கும் வசதியும் அல்ல. சேமிப்புப் பிழைகளை ஜாதகம் பகுதியில் பார்க்கவும்.',
  'Jyotara is an internal test build, not a public release. Guides are automated, not human astrologers. Traditional interpretations are not guarantees. Do not use them as medical, legal or investment advice.': 'Jyotara ஒரு உள் சோதனைப் பதிப்பு; பொதுப் பயன்பாட்டிற்கான வெளியீடு அல்ல. வழிகாட்டிகள் தானியங்கிகள்; மனித ஜோதிடர்கள் அல்ல. பாரம்பரிய விளக்கங்கள் உறுதியான கணிப்புகள் அல்ல. அவற்றை மருத்துவ, சட்ட அல்லது முதலீட்டு ஆலோசனையாகப் பயன்படுத்த வேண்டாம்.',
  'A chart request may already have reached the server. Its session is saved on this device; it has not been resent automatically. A retry may be blocked to avoid duplicate calculation charges.': 'ஜாதகக் கோரிக்கை ஏற்கெனவே சேவையகத்தை அடைந்திருக்கலாம். அதன் அமர்வு இந்தச் சாதனத்தில் சேமிக்கப்பட்டுள்ளது; தானாக மீண்டும் அனுப்பப்படவில்லை. மீண்டும் கணக்கீட்டுக் கட்டணம் ஏற்படாமல் இருக்க மறுமுயற்சி தடுக்கப்படலாம்.',
  'Saved data must be recovered or deleted before creating a new chart.': 'புதிய ஜாதகம் உருவாக்கும் முன் சேமித்த தரவுகளை மீட்டெடுக்கவும் அல்லது நீக்கவும்.',
  'The chart request was not sent because its recovery record could not be saved. Please retry.': 'மீட்புப் பதிவைச் சேமிக்க முடியாததால் ஜாதகக் கோரிக்கை அனுப்பப்படவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'AI Vedic Guide': 'AI வேத வழிகாட்டி',
  'Create your chart to start': 'தொடங்க உங்கள் ஜாதகத்தை உருவாக்கவும்',
  'Your details are shared across all guides.':
      'எல்லா வழிகாட்டிகளும் உங்கள் ஒரே பிறப்பு விவரங்களைப் பயன்படுத்துவார்கள்.',
  'Auto': 'தானாக',
  'English': 'ஆங்கிலம்',
  'Tamil': 'தமிழ்',
  'Tanglish': 'தங்கிலீஷ்',
  'Ask in English, Tamil or Tanglish…':
      'ஆங்கிலம், தமிழ் அல்லது தங்கிலீஷில் கேளுங்கள்…',
  'Send question': 'கேள்வியை அனுப்புங்கள்',
  'AI GUIDE': 'AI வழிகாட்டி',
  'TRADITIONAL VEDIC GUIDANCE': 'பாரம்பரிய வேத வழிகாட்டல்',
  'Specialist guides': 'துறை சார்ந்த வழிகாட்டிகள்',
  'One shared chart. Five focused guides for your questions.':
      'ஒரே ஜாதகம். உங்கள் கேள்விகளுக்காக ஐந்து துறை சார்ந்த வழிகாட்டிகள்.',
  'Ask naturally.': 'இயல்பாகக் கேளுங்கள்.',
  'Choose a guide, then type in English, Tamil or Tanglish. The reply follows your language.': 'ஒரு வழிகாட்டியைத் தேர்ந்தெடுத்து, ஆங்கிலம், தமிழ் அல்லது தங்கிலீஷில் கேளுங்கள். பதில் மொழியை உரையாடலில் தேர்ந்தெடுக்கலாம்.',
  'All': 'அனைத்தும்',
  'Love': 'காதல்',
  'Career': 'தொழில்',
  'Education': 'கல்வி',
  'Marriage': 'திருமணம்',
  'Daily': 'தினசரி',
  'Iniya': 'இனியா',
  'Nila': 'நிலா',
  'Vetri': 'வெற்றி',
  'Valan': 'வளன்',
  'Oli': 'ஒளி',
  'Agam': 'அகம்',
  'Arul': 'அருள்',
  'Choose a profile. Twelve focused guides for your questions.': 'ஒரு சுயவிவரத்தைத் தேர்ந்தெடுங்கள். உங்கள் கேள்விகளுக்கு பன்னிரண்டு துறைசார் வழிகாட்டிகள்.',
  'Jobs': 'வேலைவாய்ப்பு',
  'Higher Education': 'உயர்கல்வி',
  'Aadhirai': 'ஆதிரை',
  'Arivan': 'அறிவன்',
  'Medha': 'மேதா',
  'Tharagai': 'தாரகை',
  'Kaalam': 'காலம்',
  'Love & Relationships': 'காதலும் உறவுகளும்',
  'Career, Job & Business': 'தொழில், வேலை மற்றும் வணிகம்',
  'Education & Direction': 'கல்வியும் எதிர்காலத் திசையும்',
  'Marriage & Family': 'திருமணமும் குடும்பமும்',
  'Daily Guidance & Panchangam': 'தினசரி வழிகாட்டலும் பஞ்சாங்கமும்',
  'Questions about love, communication and relationship decisions.':
      'காதல், உரையாடல் மற்றும் உறவுகளில் எடுக்கும் முடிவுகள் பற்றிய கேள்விகள்.',
  'Career questions, job changes and practical preparation.':
      'வேலைத் திசை, மாற்றங்கள் பற்றிய கேள்விகள் மற்றும் நடைமுறைத் தயாரிப்பு.',
  'Study choices, exam focus and higher-education decisions.':
      'படிப்புத் தேர்வு, தேர்வுத் தயாரிப்பு மற்றும் உயர்கல்வி முடிவுகள்.',
  'Marriage questions, family relationships and thoughtful next steps.':
      'திருமணம், குடும்ப உறவுகள் மற்றும் சிந்தித்து எடுக்கும் அடுத்த படிகள்.',
  'Daily questions, Dasa, transits and Panchangam.':
      'தினசரி கேள்விகள், தசை, கோச்சாரம் மற்றும் பஞ்சாங்கம்.',
  'English · Tamil · Tanglish': 'ஆங்கிலம் · தமிழ் · தங்கிலீஷ்',
  'Your Vedic chart': 'உங்கள் வேத ஜாதகம்',
  'Add your birth details to calculate your personal chart.':
      'உங்கள் ஜாதகத்தைக் கணக்கிட பிறப்பு விவரங்களைச் சேர்க்கவும்.',
  'Approximate noon chart: Rasi and Nakshatra are provisional. Lagnam and Dasa are withheld.': 'தோராயமான நண்பகல் ஜாதகம்: ராசியும் நட்சத்திரமும் உறுதியானவை அல்ல. லக்னமும் தசையும் காட்டப்படாது.',
  'Rasi': 'ராசி',
  'Nakshatra': 'நட்சத்திரம்',
  'Pada': 'பாதம்',
  'Lagnam': 'லக்னம்',
  'Rasi lord': 'ராசி அதிபதி',
  'Nakshatra lord': 'நட்சத்திர அதிபதி',
  'Unavailable': 'கிடைக்கவில்லை',
  'Planetary positions': 'கிரக நிலைகள்',
  'Dasa–Bhukti at calculation': 'கணக்கிட்டபோதைய தசா–புக்தி',
  'Mahadasha': 'மகாதசா',
  'Antardasha': 'அந்தர்தசா',
  'Period ends': 'காலம் முடியும் நேரம்',
  'Calculated': 'கணக்கிட்ட நேரம்',
  'Sun': 'சூரியன்',
  'Moon': 'சந்திரன்',
  'Mars': 'செவ்வாய்',
  'Mercury': 'புதன்',
  'Jupiter': 'குரு',
  'Venus': 'சுக்கிரன்',
  'Saturn': 'சனி',
  'Rahu': 'ராகு',
  'Ketu': 'கேது',
  'This is a saved calculation for this session, not a continuously updated chart.': 'இது இந்த அமர்விற்காகச் சேமிக்கப்பட்ட கணக்கீடு. தொடர்ந்து புதுப்பிக்கப்படும் ஜாதகம் அல்ல.',
  'Add birth details': 'பிறப்பு விவரங்களைச் சேர்க்கவும்',
  'Change birth details': 'பிறப்பு விவரங்களை மாற்றவும்',
  'Clear this chart?': 'இந்த ஜாதகத்தை நீக்கவா?',
  'This deletes the saved chart and chat history from this device. It does not delete server usage records.': 'இந்தச் சாதனத்தில் சேமித்த ஜாதகமும் உரையாடல் வரலாறும் நீக்கப்படும். சேவையகப் பயன்பாட்டுப் பதிவுகள் நீக்கப்படாது.',
  'Cancel': 'ரத்து',
  'Clear': 'நீக்கவும்',
  'Deleting device data…': 'சாதனத்தில் உள்ள தரவு நீக்கப்படுகிறது…',
  'Retry recovery is separate from research: the server keeps an encrypted answer until this chart session expires (up to 24 hours). Expired copies are cleared when requests arrive, not on a guaranteed schedule. Request receipts remain to prevent duplicate usage.': 'மீண்டும் முயற்சிக்கும்போது பதிலைப் பெறும் வசதி ஆய்வுப் பகிர்விலிருந்து தனியானது. இந்த ஜாதக அமர்வு முடியும் வரை (அதிகபட்சம் 24 மணி நேரம்) பதில் சேவையகத்தில் மறையாக்கம் செய்து சேமிக்கப்படும். காலாவதியான பிரதிகள் அடுத்த கோரிக்கைகள் வரும்போது நீக்கப்படும்; குறிப்பிட்ட நேரத்தில் நீக்கம் உறுதி செய்யப்படவில்லை. ஒரே கேள்விக்கு மீண்டும் பயன்பாடு கணக்கிடப்படாமல் இருக்க கோரிக்கைப் பதிவுகள் வைக்கப்படும்.',
  'Please wait until device deletion finishes before creating a profile.':
      'சாதனத் தரவு நீக்கப்பட்ட பிறகு புதிய பிறப்பு விவரங்களைச் சேர்க்கவும்.',
  'Delete device profile and history':
      'சாதனத்தின் பிறப்பு விவரங்களையும் உரையாடல்களையும் நீக்கவும்',
  'Device deletion failed. Please retry.':
      'சாதனத் தரவுகளை நீக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  'Changes could not be saved on this device. Keep the app open and try again.': 'மாற்றங்களை இந்தச் சாதனத்தில் சேமிக்க முடியவில்லை. செயலியைத் திறந்தபடி வைத்திருந்து மீண்டும் முயற்சிக்கவும்.',
  'Saved data could not be opened. It has not been deleted or overwritten.': 'சேமித்த தரவுகளைத் திறக்க முடியவில்லை. அவை நீக்கப்படவோ மாற்றப்படவோ இல்லை.',
  'Device deletion failed. Saved data may return after restart. Please retry deletion.': 'சாதனத் தரவுகளை நீக்க முடியவில்லை. செயலியை மீண்டும் திறந்தால் சேமித்த தரவு திரும்பலாம். மீண்டும் நீக்க முயற்சிக்கவும்.',
  'Your birth profile': 'உங்கள் பிறப்பு விவரங்கள்',
  'Personal guidance starts with your chart':
      'உங்கள் ஜாதகத்திலிருந்து தனிப்பட்ட வழிகாட்டல் தொடங்குகிறது',
  'India · Age 13+ · Times are Indian Standard Time (UTC+05:30).':
      'இந்தியா · வயது 13+ · நேரங்கள் இந்திய நேரப்படி (UTC+05:30).',
  'Changing your birth date, time or place replaces this device’s chart and clears its previous guide chats only after the new chart is verified. If calculation fails, your existing profile and chats stay unchanged. Refreshing the same details keeps your chats.': 'பிறந்த தேதி, நேரம் அல்லது இடத்தை மாற்றினால், புதிய ஜாதகம் சரிபார்க்கப்பட்ட பிறகே இந்தச் சாதனத்தின் பழைய ஜாதகமும் உரையாடல்களும் மாற்றப்படும். கணக்கீடு தோல்வியடைந்தால் பழைய விவரங்களும் உரையாடல்களும் அப்படியே இருக்கும். அதே விவரங்களைப் புதுப்பித்தால் உரையாடல்கள் அழியாது.',
  'Name or alias (used on detailed reports)':
      'பெயர் அல்லது புனைப்பெயர் (விரிவான அறிக்கைகளில் பயன்படுத்தப்படும்)',
  'Date of birth': 'பிறந்த தேதி',
  'Select date': 'தேதியைத் தேர்ந்தெடுக்கவும்',
  'I don’t know my exact birth time': 'எனது சரியான பிறந்த நேரம் தெரியாது',
  'Exact birth time': 'சரியான பிறந்த நேரம்',
  'Select time (AM/PM)': 'நேரத்தைத் தேர்ந்தெடுக்கவும் (முற்பகல்/பிற்பகல்)',
  'A noon estimate will be used. Rasi/Nakshatra may change during the day; Lagnam and Dasa guidance are withheld.': 'நண்பகல் நேரம் தோராயமாகப் பயன்படுத்தப்படும். அன்றைய நாளில் ராசி அல்லது நட்சத்திரம் மாறக்கூடும்; லக்னம் மற்றும் தசை வழிகாட்டல் வழங்கப்படாது.',
  'Birth town, city or district': 'பிறந்த ஊர், நகரம் அல்லது மாவட்டம்',
  'Birthplace selected': 'பிறந்த இடம் தேர்ந்தெடுக்கப்பட்டது',
  'Select a birthplace from the search results.':
      'தேடல் முடிவிலிருந்து பிறந்த இடத்தைத் தேர்ந்தெடுக்கவும்.',
  'Select your birthplace from the search results below the field.': 'இடத்திற்குக் கீழே உள்ள தேடல் முடிவிலிருந்து பிறந்த இடத்தைத் தேர்ந்தெடுக்கவும்.',
  'Choose your date of birth.': 'பிறந்த தேதியைத் தேர்ந்தெடுக்கவும்.',
  'Choose your birth time or select unknown.': 'பிறந்த நேரத்தைத் தேர்ந்தெடுக்கவும் அல்லது தெரியவில்லை என்பதைத் தேர்ந்தெடுக்கவும்.',
  'Confirm consent to calculate this chart.':
      'இந்த ஜாதகத்தைக் கணக்கிட அனுமதியை உறுதிசெய்யவும்.',
  'Searching…': 'தேடுகிறது…',
  'Search birthplace': 'பிறந்த இடத்தைத் தேடவும்',
  'Location data: astrology calculation service':
      'இட விவரங்கள்: astrology calculation service',
  'India · IST': 'இந்தியா · இந்திய நேரம்',
  'I am 13+ and agree to process my birth details for automated Vedic guidance.': 'எனக்கு 13 வயது நிறைவடைந்துள்ளது. தானியங்கி வேத ஜோதிட வழிகாட்டலுக்காக எனது பிறப்பு விவரங்களைப் பயன்படுத்தச் சம்மதிக்கிறேன்.',
  'Name or alias, selected gender and birth details go to astrology calculation service when a detailed report is requested; chart facts and your question go to the language service. Your chart and chat history are saved in encrypted storage on this device. Delete them from the Chart tab. Creating a profile turns optional research sharing off; you can choose it separately in Account. For a connected profile, the Chart tab can also delete server chart and answer copies. Minimal usage records remain; backup copies expire within eight days.': 'விரிவான அறிக்கையைக் கோரும்போது பெயர் அல்லது புனைப்பெயர், தேர்ந்தெடுத்த பாலினம் மற்றும் பிறப்பு விவரங்கள் ஜாதகக் கணக்கீட்டுச் சேவைக்கு அனுப்பப்படும்; ஜாதக விவரங்களும் உங்கள் கேள்வியும் மொழிச் சேவைக்கும் அனுப்பப்படும். உங்கள் ஜாதகமும் உரையாடல்களும் இந்தச் சாதனத்தில் மறையாக்கம் செய்து சேமிக்கப்படும். ஜாதகம் பகுதியில் அவற்றை நீக்கலாம். புதிய பிறப்பு விவரங்களை உருவாக்கும்போது ஆய்வுக்கான விருப்பப் பகிர்வு முடக்கப்படும்; கணக்கு பகுதியில் தனியாகத் தேர்ந்தெடுக்கலாம். இணைக்கப்பட்ட பிறப்பு விவரத்திற்கு, ஜாதகம் பகுதியில் சேவையக ஜாதக மற்றும் பதில் நகல்களையும் நீக்கலாம். குறைந்தபட்ச பயன்பாட்டுப் பதிவுகள் இருக்கும்; காப்பு நகல்கள் எட்டு நாட்களுக்குள் காலாவதியாகும்.',
  'Calculating your chart…': 'உங்கள் ஜாதகம் கணக்கிடப்படுகிறது…',
  'Calculate my chart': 'என் ஜாதகத்தைக் கணக்கிடவும்',
  'Traditional guidance is interpretive, not a guarantee of future events. Pilot usage limits apply.': 'பாரம்பரிய வழிகாட்டல் ஒரு விளக்கம் மட்டுமே; எதிர்கால நிகழ்வுகளுக்கான உறுதி அல்ல. சோதனைப் பயன்பாட்டு வரம்புகள் பொருந்தும்.',
  'Choose your date, time and birthplace, then confirm consent.': 'பிறந்த தேதி, நேரம் மற்றும் இடத்தைத் தேர்ந்தெடுத்து, உங்கள் சம்மதத்தை உறுதிப்படுத்தவும்.',
  'No Indian birthplace found. Try the nearest town name in English.': 'இந்தியாவில் அந்த இடம் கிடைக்கவில்லை. அருகிலுள்ள ஊரின் பெயரை ஆங்கிலத்தில் முயற்சிக்கவும்.',
  'Place search is unavailable. Please retry; no chart was requested.': 'இடத்தைத் தேட முடியவில்லை. மீண்டும் முயற்சிக்கவும்; ஜாதகக் கணக்கீடு கோரப்படவில்லை.',
  'The chart could not be verified. Please try again later.':
      'ஜாதகத்தைச் சரிபார்க்க முடியவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.',
  'Welcome': 'வணக்கம்',
  'What would you like\nguidance about?': 'எதைப் பற்றி\nவழிகாட்டல் வேண்டும்?',
  'Your chart': 'உங்கள் ஜாதகம்',
  'Create birth profile': 'பிறப்பு விவரங்களைச் சேர்க்கவும்',
  'View my chart': 'என் ஜாதகத்தைப் பார்க்கவும்',
  'Home': 'முகப்பு',
  'Guides': 'வழிகாட்டிகள்',
  'Ask': 'கேளுங்கள்',
  'Chart': 'ஜாதகம்',
  'Account': 'கணக்கு',
  'Your account': 'உங்கள் கணக்கு',
  'Birth profile': 'பிறப்பு விவரங்கள்',
  'View or change your details': 'உங்கள் விவரங்களைப் பார்க்கவும் மாற்றவும்',
  'Plans & question balance': 'திட்டங்கள் மற்றும் மீதமுள்ள கேள்விகள்',
  'Pilot limits · Payments not enabled':
      'சோதனை வரம்புகள் · கட்டணம் செயல்படுத்தப்படவில்லை',
  'Chat history': 'உரையாடல் வரலாறு',
  'Saved privately on this device':
      'இந்தச் சாதனத்தில் தனிப்பட்ட முறையில் சேமிக்கப்பட்டுள்ளது',
  'App language': 'செயலி மொழி',
  'English or Tamil menus': 'ஆங்கிலம் அல்லது தமிழ் பட்டிகள்',
  'Chat language': 'பதில் மொழி',
  'Choose a saved reply preference': 'பதில்களுக்கான மொழியைத் தேர்ந்தெடுக்கவும்',
  'Privacy & consent': 'தனியுரிமை மற்றும் சம்மதம்',
  'Research storage is off': 'ஆய்வுக்கான சேமிப்பு முடக்கப்பட்டுள்ளது',
  'Research sharing is on for this session':
      'இந்த அமர்வில் ஆய்வுக்கான பகிர்வு இயங்குகிறது',
  'Research sharing is off': 'ஆய்வுக்கான பகிர்வு முடக்கப்பட்டுள்ளது',
  'Your birth details are sensitive. Manage or delete your saved profile from the Chart tab. Research sharing is optional.': 'உங்கள் பிறப்பு விவரங்கள் தனிப்பட்டவை. ஜாதகம் பகுதியில் சேமித்த விவரங்களை நிர்வகிக்கலாம் அல்லது நீக்கலாம். ஆய்வுக்கான பகிர்வு உங்கள் விருப்பம்.',
  'About this build': 'இந்தப் பதிப்பு பற்றி',
  'Internal integration test': 'உள் ஒருங்கிணைப்புச் சோதனை',
  'Phone verified': 'தொலைபேசி எண் உறுதிசெய்யப்பட்டது',
  'Signed in': 'உள்நுழைந்துள்ளீர்கள்',
  'Not signed in': 'உள்நுழையவில்லை',
  'Sign out': 'வெளியேறு',
  'Your saved profiles stay with this account':
      'சேமித்த ஜாதகங்கள் இந்தக் கணக்கில் பாதுகாப்பாக இருக்கும்',
  'Local test session': 'சாதனச் சோதனை அமர்வு',
  'Not signed in · OTP not configured': 'உள்நுழையவில்லை · OTP அமைக்கப்படவில்லை',
  'Close': 'மூடு',
  'Reply language': 'பதில் மொழி',
  'Language could not be saved. Please try again.':
      'மொழியைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
};

class AppLanguageSwitch extends StatelessWidget {
  const AppLanguageSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final preferences = context
        .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
        ?.notifier;
    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        for (final option in [('en', 'English'), ('ta', 'தமிழ்')])
          TextButton(
            onPressed: preferences == null
                ? null
                : () async {
                    try {
                      await preferences.set(option.$1);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save language. Please retry.',
                            ),
                          ),
                        );
                      }
                    }
                  },
            style: TextButton.styleFrom(
              foregroundColor: preferences?.value == option.$1
                  ? BronzePalette.gold
                  : BronzePalette.muted,
            ),
            child: Text(option.$2),
          ),
      ],
    );
  }
}

String? tamilBirthStar(String value) {
  final key = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  const names = <String, String>{
    'aswini': 'அஸ்வினி',
    'ashwini': 'அஸ்வினி',
    'ashvini': 'அஸ்வினி',
    'bharani': 'பரணி',
    'krittika': 'கார்த்திகை',
    'kritika': 'கார்த்திகை',
    'karthigai': 'கார்த்திகை',
    'rohini': 'ரோகிணி',
    'mrigashira': 'மிருகசீரிடம்',
    'mrigasira': 'மிருகசீரிடம்',
    'mrigashirsha': 'மிருகசீரிடம்',
    'ardra': 'திருவாதிரை',
    'arudra': 'திருவாதிரை',
    'punarvasu': 'புனர்பூசம்',
    'pushya': 'பூசம்',
    'pushyami': 'பூசம்',
    'ashlesha': 'ஆயில்யம்',
    'aslesha': 'ஆயில்யம்',
    'magha': 'மகம்',
    'makha': 'மகம்',
    'purvaphalguni': 'பூரம்',
    'poorvaphalguni': 'பூரம்',
    'uttaraphalguni': 'உத்திரம்',
    'hasta': 'அஸ்தம்',
    'chitra': 'சித்திரை',
    'chitta': 'சித்திரை',
    'swati': 'சுவாதி',
    'swathi': 'சுவாதி',
    'vishakha': 'விசாகம்',
    'visakha': 'விசாகம்',
    'anuradha': 'அனுஷம்',
    'jyeshtha': 'கேட்டை',
    'jyestha': 'கேட்டை',
    'mula': 'மூலம்',
    'moola': 'மூலம்',
    'purvaashadha': 'பூராடம்',
    'purvashada': 'பூராடம்',
    'poorvashada': 'பூராடம்',
    'uttaraashadha': 'உத்திராடம்',
    'uttarashada': 'உத்திராடம்',
    'shravana': 'திருவோணம்',
    'sravana': 'திருவோணம்',
    'dhanishta': 'அவிட்டம்',
    'dhanishtha': 'அவிட்டம்',
    'shatabhisha': 'சதயம்',
    'satabhisha': 'சதயம்',
    'shatabhishak': 'சதயம்',
    'purvabhadrapada': 'பூரட்டாதி',
    'poorvabhadrapada': 'பூரட்டாதி',
    'uttarabhadrapada': 'உத்திரட்டாதி',
    'revati': 'ரேவதி',
    'revathi': 'ரேவதி',
  };
  return names[key];
}

class CompactLanguageSwitch extends StatelessWidget {
  const CompactLanguageSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final preferences = context
        .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
        ?.notifier;
    return PopupMenuButton<String>(
      tooltip: uiText(context, 'Language'),
      initialValue: preferences?.value ?? 'en',
      onSelected: (language) async {
        try {
          await preferences?.set(language);
        } catch (_) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save language. Please retry.'),
              ),
            );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate, size: 13, color: BronzePalette.muted),
            const SizedBox(width: 6),
            Text(
              preferences?.value == 'ta' ? 'தமிழ்' : 'English',
              style: const TextStyle(fontSize: 11, color: BronzePalette.muted),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 14, color: BronzePalette.muted),
          ],
        ),
      ),
    );
  }
}
