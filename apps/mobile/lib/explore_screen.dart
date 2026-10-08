import 'bronze_theme.dart';
import 'birth_form.dart';
import 'location_search_sheet.dart';
import 'explore_meanings.dart';
import 'services/remote_config.dart';
import 'services/user_journey.dart';
import 'brand_mark.dart';

import 'package:flutter/material.dart';

import 'main.dart'
    show profileSession, BirthProfileScreen, AccountScreen, MainTabScope;
import 'discovery_screens.dart'
    show discoveryRequest, readingLanguage, zodiacIds;
import 'south_chart.dart';
import 'launch_intro.dart';
import 'services/ui_language.dart';
import 'services/profile_session.dart';
import 'chat_availability.dart';

String ex(BuildContext c, String en, String ta) =>
    readingLanguage(c) == 'ta' ? ta : en;
String dayString(DateTime d) => d.toIso8601String().substring(0, 10);
String calendarTime(dynamic s) {
  final d = DateTime.tryParse('$s')
      ?.toUtc()
      .add(const Duration(hours: 5, minutes: 30));
  return d == null
      ? '—'
      : '${dayString(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} IST';
}

/// Dasha provider boundaries are calendar dates, not precise clock times.
String dashaDate(dynamic value) {
  final d = DateTime.tryParse('$value')
      ?.toUtc()
      .add(const Duration(hours: 5, minutes: 30));
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _periodMeaning(BuildContext context, String name) {
  final key = name
      .replaceAll(RegExp(r'mahadasha|dasha|bhukti', caseSensitive: false), '')
      .trim();
  for (final entry in planetMeanings.entries) {
    if (key.toLowerCase().contains(entry.key.toLowerCase())) {
      return ex(
        context,
        'Traditional themes: ${entry.value.$1}',
        'பாரம்பரிய கருத்துகள்: ${entry.value.$2}',
      );
    }
  }
  return ex(
    context,
    'A traditional planetary period within your birth-chart timeline.',
    'உங்கள் ஜாதகத்தின் பாரம்பரிய கிரகக் காலம்.',
  );
}

bool activePeriod(Map p, DateTime now) {
  final a = DateTime.tryParse('${p['start']}'),
      b = DateTime.tryParse('${p['end']}');
  return a != null && b != null && !now.isBefore(a) && now.isBefore(b);
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !MainTabScope.contains(context) &&
          ModalRoute.of(context)?.isCurrent != false) {
        userJourney.screen('explore');
      }
    });
  }

  void open(int kind) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'reading'),
      builder: (_) => ExploreDetail(kind: kind, session: profileSession),
    ),
  );
  void quick(String kind) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'reading'),
      builder: (_) => ExploreQuickPage(kind: kind, session: profileSession),
    ),
  );
  Widget tile(
    String emoji,
    String en,
    String ta,
    String sub,
    VoidCallback tap,
  ) => EntranceReveal(
    child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        leading: en == 'Know myself'
            ? const Icon(
                Icons.person_search_outlined,
                color: BronzePalette.gold,
                size: 29,
              )
            : Text(emoji, style: const TextStyle(fontSize: 29)),
        title: Text(ex(context, en, ta)),
        subtitle: sub.isEmpty
            ? null
            : Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: BronzePalette.gold),
        onTap: tap,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: profileSession,
      builder: (context, _) {
        RemoteConfigScope.watch(context);
        final facts = profileSession.facts;
        final sign = SouthIndianChart.signIndex(facts?['rashi']);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!MainTabScope.contains(context))
                    Row(
                      children: [
                        IconButton(
                          tooltip: ex(context, 'Profile', 'சுயவிவரம்'),
                          icon: const Icon(Icons.person_outline_rounded),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AccountScreen(),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Jyotara',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'JyotaraEditorial',
                              fontSize: 25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!MainTabScope.contains(context))
                    const AppLanguageSwitch(),
                  Text(
                    ex(context, 'Explore astrology', 'ஜோதிடம் அறிவோம்'),
                    style: const TextStyle(
                      fontFamily: 'JyotaraEditorial',
                      fontSize: 29,
                    ),
                  ),
                  Text(
                    ex(
                      context,
                      'Discover a little more about you.',
                      'உங்களை எளிதாக அறியுங்கள்.',
                    ),
                    style: const TextStyle(color: BronzePalette.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (remoteConfig.announcement.isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(remoteConfig.announcement),
                      ),
                    ),
                  for (final card in remoteConfig.cards)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(card['title']!),
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => SafeArea(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(card['body']!),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  EntranceReveal(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => quick('rasi'),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              if (sign >= 0)
                                RasiFigure(
                                  index: sign,
                                  size: 100,
                                  goldStyle: true,
                                )
                              else
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 64,
                                  color: BronzePalette.gold,
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex(context, 'My Rasi', 'என் ராசி'),
                                      style: const TextStyle(
                                        color: BronzePalette.gold,
                                      ),
                                    ),
                                    Text(
                                      sign < 0
                                          ? ex(
                                              context,
                                              'Add birth details',
                                              'பிறப்பு விவரங்கள் சேர்க்க',
                                            )
                                          : uiText(
                                              context,
                                              SouthIndianChart.signs[sign],
                                            ),
                                      style: const TextStyle(
                                        fontFamily: 'JyotaraEditorial',
                                        fontSize: 25,
                                      ),
                                    ),
                                    Text(
                                      ex(
                                        context,
                                        'Discover your nature →',
                                        'உங்கள் இயல்பை அறிய →',
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  tile(
                    '✨',
                    'My birth star',
                    'என் நட்சத்திரம்',
                    facts == null
                        ? ''
                        : uiText(context, '${facts['nakshatra'] ?? ''}'),
                    () => quick('star'),
                  ),
                  tile(
                    '🪐',
                    'My Dasha',
                    'என் தசை',
                    ex(
                      context,
                      'Your current life phase',
                      'தற்போதைய வாழ்க்கைக் காலம்',
                    ),
                    () => open(3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ex(context, 'Made personal', 'உங்களுக்காக'),
                    style: const TextStyle(fontSize: 19),
                  ),
                  tile(
                    '☷',
                    'My birth chart',
                    'என் ஜாதகம்',
                    ex(
                      context,
                      'Your planets and signs',
                      'உங்கள் கிரகங்கள் · ராசிகள்',
                    ),
                    () => open(2),
                  ),
                  tile(
                    '🌿',
                    'Know myself',
                    'என்னைப் பற்றி',
                    ex(
                      context,
                      'Strengths and personal growth',
                      'திறன்கள் · தனி வளர்ச்சி',
                    ),
                    () => open(4),
                  ),
                  tile(
                    '📅',
                    'Tamil calendar',
                    'தமிழ் நாட்காட்டி',
                    ex(
                      context,
                      'Timings and day details',
                      'நேரங்கள் · நாள் விவரம்',
                    ),
                    () => open(1),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Compact, local explanations: no translation request or paid reading on open.
class ExploreQuickPage extends StatelessWidget {
  const ExploreQuickPage({
    super.key,
    required this.kind,
    required this.session,
  });
  final String kind;
  final ProfileSession session;
  static const traits = [
    ('Initiative · Courage · Energy', 'முன்முயற்சி · துணிவு · ஆற்றல்'),
    ('Patience · Stability · Care', 'பொறுமை · நிலைத்தன்மை · அக்கறை'),
    (
      'Curiosity · Communication · Adaptability',
      'ஆர்வம் · உரையாடல் · நெகிழ்வு',
    ),
    ('Care · Belonging · Sensitivity', 'அக்கறை · பாசம் · உணர்வு'),
    (
      'Confidence · Expression · Leadership',
      'தன்னம்பிக்கை · வெளிப்பாடு · தலைமை',
    ),
    ('Detail · Service · Practicality', 'நுணுக்கம் · சேவை · நடைமுறை'),
    ('Balance · Cooperation · Harmony', 'சமநிலை · ஒத்துழைப்பு · இணக்கம்'),
    ('Depth · Determination · Change', 'ஆழம் · உறுதி · மாற்றம்'),
    ('Learning · Exploration · Meaning', 'கற்றல் · தேடல் · நோக்கம்'),
    ('Discipline · Patience · Responsibility', 'ஒழுக்கம் · பொறுமை · பொறுப்பு'),
    ('Ideas · Community · Independence', 'சிந்தனை · சமூகம் · சுதந்திரம்'),
    (
      'Compassion · Imagination · Sensitivity',
      'அன்பு · கற்பனை · மென்மையான மனம்',
    ),
  ];
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final f = session.facts;
      final sign = SouthIndianChart.signIndex(f?['rashi']);
      final personal = kind == 'rasi' || kind == 'star';
      final title = switch (kind) {
        'rasi' => ex(context, 'My Rasi', 'என் ராசி'),
        'star' => ex(context, 'My birth star', 'என் நட்சத்திரம்'),
        'planets' => ex(context, 'The nine planets', 'ஒன்பது கிரகங்கள்'),
        _ => ex(context, 'The 12 houses', '12 பாவங்கள்'),
      };
      final rows = kind == 'planets'
          ? <(String, String, String)>[
              ('☀️', 'Sun · Identity', 'சூரியன் · தனித்தன்மை'),
              ('🌙', 'Moon · Emotions', 'சந்திரன் · மனம்'),
              ('🔥', 'Mars · Drive', 'செவ்வாய் · துணிவு'),
              ('💬', 'Mercury · Communication', 'புதன் · பேச்சுத்திறன்'),
              ('📚', 'Jupiter · Learning', 'குரு · கற்றல்'),
              ('🌸', 'Venus · Beauty', 'சுக்கிரன் · அழகு'),
              ('🪐', 'Saturn · Discipline', 'சனி · ஒழுக்கம்'),
              ('🧭', 'Rahu · Desire', 'ராகு · ஆசை'),
              ('🌿', 'Ketu · Detachment', 'கேது · பற்றின்மை'),
            ]
          : <(String, String, String)>[
              ('1', 'Self', 'நீங்கள்'),
              ('2', 'Family & resources', 'குடும்பம் · வளம்'),
              ('3', 'Effort & communication', 'முயற்சி · தொடர்பு'),
              ('4', 'Home', 'வீடு'),
              ('5', 'Creativity', 'படைப்பாற்றல்'),
              ('6', 'Service & routines', 'சேவை · பழக்கங்கள்'),
              ('7', 'Partnership', 'துணை'),
              ('8', 'Change', 'மாற்றம்'),
              ('9', 'Learning & beliefs', 'கற்றல் · நம்பிக்கை'),
              ('10', 'Work', 'தொழில்'),
              ('11', 'Friends & goals', 'நட்பு · இலக்குகள்'),
              ('12', 'Rest & reflection', 'ஓய்வு · சிந்தனை'),
            ];
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppLanguageSwitch(),
            if (personal && f == null) ...[
              Text(
                ex(
                  context,
                  'Add your birth details first.',
                  'முதலில் பிறப்பு விவரங்களைச் சேர்க்கவும்.',
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BirthProfileScreen(),
                  ),
                ),
                child: const UiText('Add birth details'),
              ),
            ] else if (kind == 'rasi') ...[
              if (sign >= 0)
                Center(
                  child: EntranceReveal(
                    child: RasiFigure(index: sign, size: 180, goldStyle: true),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                sign >= 0
                    ? uiText(context, SouthIndianChart.signs[sign])
                    : ex(context, 'Rasi unavailable', 'ராசி கிடைக்கவில்லை'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'JyotaraEditorial',
                  fontSize: 28,
                ),
              ),
              if (sign >= 0)
                for (final point in ex(
                  context,
                  traits[sign].$1,
                  traits[sign].$2,
                ).split(' · '))
                  EntranceReveal(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Text(
                          '✦',
                          style: TextStyle(color: BronzePalette.gold),
                        ),
                        title: Text(point),
                        trailing: const Icon(Icons.info_outline),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                            title: Text(point),
                            content: Text(rasiTraitMeaning(point)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog),
                                child: const UiText('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              Text(
                ex(
                  context,
                  'Traditional Rasi traits',
                  'பாரம்பரிய ராசி இயல்புகள்',
                ),
                textAlign: TextAlign.center,
              ),
              if (!session.birthTimeKnown)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ex(
                                context,
                                'Birth time unknown · Rasi may change.',
                                'பிறந்த நேரம் தெரியவில்லை · ராசி மாறலாம்.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ] else if (kind == 'star') ...[
              const Center(child: Text('✨', style: TextStyle(fontSize: 72))),
              Text(
                uiText(context, '${f?['nakshatra'] ?? '—'}'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 27),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(ex(context, 'Star ruler', 'நட்சத்திர அதிபதி')),
                  subtitle: Text(
                    uiText(context, '${f?['nakshatraLord'] ?? '—'}'),
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    ex(
                      context,
                      'Your Moon’s birth-star position',
                      'பிறப்பில் சந்திரன் இருந்த நட்சத்திரம்',
                    ),
                  ),
                ),
              ),
              if (!session.birthTimeKnown)
                Text(
                  ex(
                    context,
                    'Birth time unknown · Star may change.',
                    'பிறந்த நேரம் தெரியவில்லை · நட்சத்திரம் மாறலாம்.',
                  ),
                ),
            ] else ...[
              Text(
                ex(
                  context,
                  'Tap a topic for a simple explanation.',
                  'எளிய விளக்கத்திற்கு ஒரு தலைப்பைத் தொடுங்கள்.',
                ),
              ),
              for (var i = 0; i < rows.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(ex(context, rows[i].$2, rows[i].$3)),
                    leading: kind == 'houses'
                        ? Text(
                            '${i + 1}',
                            style: const TextStyle(color: BronzePalette.gold),
                          )
                        : const Icon(
                            Icons.auto_awesome_outlined,
                            color: BronzePalette.gold,
                          ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    children: [
                      Text(
                        kind == 'planets'
                            ? ex(
                                context,
                                planetMeanings.values.elementAt(i).$1,
                                planetMeanings.values.elementAt(i).$2,
                              )
                            : ex(
                                context,
                                houseMeanings[i].$1,
                                houseMeanings[i].$2,
                              ),
                      ),
                    ],
                  ),
                ),
              Text(
                ex(context, 'Traditional meanings', 'பாரம்பரிய விளக்கங்கள்'),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ExploreDetail extends StatefulWidget {
  const ExploreDetail({super.key, required this.kind, required this.session});
  final int kind;
  final ProfileSession session;
  @override
  State<ExploreDetail> createState() => _ExploreDetailState();
}

class _ExploreDetailState extends State<ExploreDetail> {
  DateTime date = DateTime.now().toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  Map<String, dynamic>? data;
  String? error, language;
  bool busy = false;
  int generation = 0;
  int profileRevision = 0;
  double? lat, lon;
  String? location;
  int? selectedSign;
  ProfileSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        userJourney.screen('reading');
      }
    });
    profileRevision = session.revision;
    session.addListener(profileChanged);
    lat = session.birthInput?.latitude;
    lon = session.birthInput?.longitude;
    location = session.birthplaceLabel;
  }

  void profileChanged() {
    if (session.revision == profileRevision || !mounted) return;
    setState(() {
      profileRevision = session.revision;
      generation++;
      busy = false;
      data = null;
      error = null;
      selectedSign = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = readingLanguage(context);
    if (next != language) {
      language = next;
      data = null;
      busy = false;
      generation++;
    }
  }

  @override
  void dispose() {
    generation++;
    session.removeListener(profileChanged);
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    if (widget.kind == 0 &&
        SouthIndianChart.signIndex(session.facts?['rashi']) < 0) {
      return;
    }
    final rev = ++generation;
    setState(() {
      busy = true;
      error = null;
      data = null;
    });
    try {
      final value = widget.kind == 0
          ? await discoveryRequest('/api/horoscope/daily', {
              'sign':
                  zodiacIds[SouthIndianChart.signIndex(
                    session.facts?['rashi'],
                  )],
              'date': dayString(date),
              'language': language,
            })
          : await discoveryRequest('/api/explore/panchang', {
              'date': dayString(date),
              'latitude': lat,
              'longitude': lon,
              'language': language,
            });
      if (mounted && rev == generation) setState(() => data = value);
    } catch (e) {
      if (mounted && rev == generation) {
        setState(
          () => error = ex(
            context,
            'Could not load this reading. Check your connection and retry.',
            'வாசிப்பைப் பெற முடியவில்லை. இணையத்தைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      if (mounted && rev == generation) setState(() => busy = false);
    }
  }

  Future<void> pickPlace() async {
    final row = await pickIndianLocation(
      context,
      session,
      title: 'Current city',
    );
    if (row == null || !mounted) return;
    setState(() {
      lat = (row[6] as num).toDouble();
      lon = (row[7] as num).toDouble();
      location = '${row[1]}, ${row[2]}';
      data = null;
      generation++;
    });
  }

  Widget card(String title, String body) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    ),
  );
  Widget reading(String title, String topic, String question) => ReadingPanel(
    key: ValueKey("${session.revision}:$language:$question"),
    session: session,
    title: title,
    topic: topic,
    question: question,
    language: language ?? 'en',
  );
  @override
  Widget build(BuildContext context) {
    final titles = [
      ex(context, 'Your Day', 'உங்கள் நாள்'),
      ex(context, 'Tamil Panchang', 'தமிழ் பஞ்சாங்கம்'),
      ex(context, 'Explore my chart', 'என் ஜாதகத்தை அறிய'),
      ex(context, 'My Current Dasha', 'எனது தற்போதைய தசை'),
      ex(context, 'My Life Reading', 'என் வாழ்க்கை வாசிப்பு'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[widget.kind])),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final facts = session.facts;
          final known = session.birthTimeKnown;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (widget.kind != 1 && facts == null) ...[
                Text(
                  ex(
                    context,
                    'Add your birth details to open your readings.',
                    'உங்கள் வாசிப்புகளுக்கு பிறப்பு விவரங்களைச் சேர்க்கவும்.',
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const BirthProfileScreen(),
                    ),
                  ),
                  child: const UiText('Add birth details'),
                ),
              ] else ...[
                if (widget.kind != 1)
                  Text(
                    '${session.nickname} · ${uiText(context, '${facts?['rashi'] ?? ''}')}',
                  ),
                if (widget.kind == 0) ...[
                  Text(
                    ex(
                      context,
                      'Three short readings for your Rasi. These are sign-based, not a personalised transit forecast.',
                      'உங்கள் ராசிக்கான மூன்று சுருக்கமான வாசிப்புகள். இவை பொதுவான ராசிபலன்கள்.',
                    ),
                  ),
                  Text(dayString(date)),
                  FilledButton(
                    onPressed:
                        busy || SouthIndianChart.signIndex(facts?['rashi']) < 0
                        ? null
                        : load,
                    child: Text(ex(context, 'Read my day', 'இன்றைய பலன்')),
                  ),
                  for (final row in (data?['sections'] as List? ?? []).where(
                    (r) => ['General', 'Love', 'Career'].contains(r['title']),
                  ))
                    card(
                      ex(
                        context,
                        {
                          'General': 'Personal focus',
                          'Love': 'Relationships',
                          'Career': 'Work',
                        }[row['title']]!,
                        {
                          'General': 'தனிப்பட்ட கவனம்',
                          'Love': 'உறவுகள்',
                          'Career': 'வேலை',
                        }[row['title']]!,
                      ),
                      '${row['text']}',
                    ),
                ],
                if (widget.kind == 1) ...[
                  Text(
                    ex(
                      context,
                      'Choose the place where you will be on this date. Times are in IST.',
                      'அந்த நாளில் நீங்கள் இருக்கும் ஊரைத் தேர்ந்தெடுக்கவும். நேரங்கள் இந்திய நேரப்படி.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (location != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${ex(context, 'Selected place', 'தேர்ந்தெடுத்த ஊர்')}: $location',
                        softWrap: true,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : pickPlace,
                    icon: const Icon(Icons.place_outlined),
                    label: Text(
                      ex(
                        context,
                        'Choose your current city / native place',
                        'தற்போதைய ஊர் / சொந்த ஊரைத் தேர்ந்தெடுக்கவும்',
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(dayString(date)),
                    onPressed: busy
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final v = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: now.subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (v != null && mounted) {
                              setState(() {
                                date = v;
                                data = null;
                                generation++;
                              });
                            }
                          },
                  ),
                  FilledButton(
                    onPressed: busy || lat == null ? null : load,
                    child: Text(
                      ex(context, 'Show Panchang', 'பஞ்சாங்கம் பார்க்க'),
                    ),
                  ),
                  if (data != null) ...[
                    if (data!['timingsStatus'] == 'partial')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          ex(
                            context,
                            'Some traditional timings are temporarily unavailable.',
                            'சில பாரம்பரிய நேரங்கள் தற்போது கிடைக்கவில்லை.',
                          ),
                        ),
                      ),
                    card(
                      ex(context, 'Sunrise · Sunset', 'சூரிய உதயம் · அஸ்தமனம்'),
                      '${calendarTime(data!['sunrise'])}\n${calendarTime(data!['sunset'])}',
                    ),
                    for (final group in [
                      ('tithi', ex(context, 'Tithi', 'திதி')),
                      ('nakshatra', ex(context, 'Nakshatra', 'நட்சத்திரம்')),
                      ('yoga', ex(context, 'Yoga', 'யோகம்')),
                      ('karana', ex(context, 'Karana', 'கரணம்')),
                      (
                        'timings',
                        ex(
                          context,
                          'Traditional timings',
                          'பாரம்பரிய நேரங்கள்',
                        ),
                      ),
                    ])
                      card(
                        group.$2,
                        (data![group.$1] as List? ?? [])
                            .map(
                              (r) =>
                                  '${r['name']}\n${r['start'] == null ? '' : "${calendarTime(r['start'])} → "}${r['end'] == null ? ex(context, 'End time not supplied', 'முடிவு நேரம் வழங்கப்படவில்லை') : calendarTime(r['end'])}',
                            )
                            .join('\n\n'),
                      ),
                  ],
                ],
                if (widget.kind == 2) ...[
                  Text(
                    ex(
                      context,
                      'Tap a sign to explore its planets and house.',
                      'ராசியைத் தொட்டு அதன் கிரகங்களையும் பாவத்தையும் அறியுங்கள்.',
                    ),
                  ),
                  SouthIndianChart(
                    facts: facts!,
                    onSignTap: (v) => setState(() => selectedSign = v),
                  ),
                  if (selectedSign != null) ...[
                    card(
                      uiText(context, SouthIndianChart.signs[selectedSign!]),
                      ex(
                            context,
                            'Planets in this sign: ',
                            'இந்த ராசியில் உள்ள கிரகங்கள்: ',
                          ) +
                          (facts['planets'] as List)
                              .where(
                                (p) =>
                                    SouthIndianChart.signIndex(p['rasi']) ==
                                    selectedSign,
                              )
                              .map((p) => uiText(context, p['name']))
                              .join(', '),
                    ),
                    if (known &&
                        SouthIndianChart.signIndex(facts['lagna']) >= 0)
                      card(
                        ex(
                          context,
                          'House from ascendant',
                          'லக்னத்திலிருந்து பாவம்',
                        ),
                        '${(selectedSign! - SouthIndianChart.signIndex(facts['lagna']) + 12) % 12 + 1}',
                      ),
                    reading(
                      ex(
                        context,
                        'Read this part of my chart',
                        'இந்த ஜாதகப் பகுதியின் விளக்கம்',
                      ),
                      'Daily',
                      'Explain the ${SouthIndianChart.signs[selectedSign!]} sign in my birth chart, its planets and house if birth time is known.',
                    ),
                  ],
                  for (final p in facts['planets'] as List)
                    ExpansionTile(
                      title: Text(
                        '${uiText(context, p['name'])} · ${uiText(context, p['rasi'])}',
                      ),
                      subtitle: Text(
                        '${(p['degree'] as num).toStringAsFixed(2)}°',
                      ),
                      children: [
                        reading(
                          ex(context, 'Planet reading', 'கிரக விளக்கம்'),
                          'Daily',
                          'What does ${p['name']} in ${p['rasi']} mean in my birth chart?',
                        ),
                      ],
                    ),
                ],
                if (widget.kind == 3) ...[
                  if (!known)
                    card(
                      ex(
                        context,
                        'Birth time unknown',
                        'பிறந்த நேரம் தெரியவில்லை',
                      ),
                      ex(
                        context,
                        'Dasha dates are not available without an accurate birth time.',
                        'சரியான பிறந்த நேரம் இல்லாமல் தசை தேதிகளைக் கணிக்க முடியாது.',
                      ),
                    )
                  else if (session.dashaTimeline.isEmpty)
                    card(
                      ex(
                        context,
                        'Timeline unavailable',
                        'காலவரிசை கிடைக்கவில்லை',
                      ),
                      ex(
                        context,
                        'This saved chart has no complete dasha timeline. Refresh the birth chart to request it.',
                        'சேமித்த ஜாதகத்தில் முழுத் தசை விவரம் இல்லை. பிறப்பு ஜாதகத்தைப் புதுப்பிக்கவும்.',
                      ),
                    )
                  else ...[
                    for (final current in session.dashaTimeline.where(
                      (p) => activePeriod(p, DateTime.now()),
                    )) ...[
                      card(
                        ex(context, 'Your current Dasha', 'உங்கள் நடப்பு தசை'),
                        '${uiText(context, current['name'])}\n${_periodMeaning(context, '${current['name']}')}',
                      ),
                      for (final sub
                          in (current['antardasha'] as List? ?? [])
                              .whereType<Map>()
                              .where((p) => activePeriod(p, DateTime.now())))
                        card(
                          ex(
                            context,
                            'Current Bhukti · within this Dasha',
                            'இந்த தசையின் நடப்பு புக்தி',
                          ),
                          '${uiText(context, '${sub['name']}')}\n${_periodMeaning(context, '${sub['name']}')}',
                        ),
                    ],
                    Text(
                      ex(
                        context,
                        'Current period is selected using today’s date. Tap a period to see its bhuktis.',
                        'இன்றைய தேதிப்படி நடப்பு தசை காட்டப்படுகிறது. புக்திகளைப் பார்க்க தசையைத் தொடுங்கள்.',
                      ),
                    ),
                    for (final p in session.dashaTimeline)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          initiallyExpanded: activePeriod(p, DateTime.now()),
                          leading: Icon(
                            activePeriod(p, DateTime.now())
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: BronzePalette.accent,
                          ),
                          title: Text(
                            '${uiText(context, p['name'])}${activePeriod(p, DateTime.now()) ? ex(context, ' · Current', ' · நடப்பு') : ''}',
                          ),
                          subtitle: Text(
                            '${dashaDate(p['start'])} → ${dashaDate(p['end'])}',
                          ),
                          children: [
                            for (final a in p['antardasha'] as List? ?? [])
                              ListTile(
                                title: Text(uiText(context, '${a['name']}')),
                                subtitle: Text(
                                  '${dashaDate(a['start'])} → ${dashaDate(a['end'])}',
                                ),
                                trailing: activePeriod(a, DateTime.now())
                                    ? const Icon(
                                        Icons.arrow_back,
                                        color: BronzePalette.accent,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
                if (widget.kind == 4) ...[
                  if (!known) ...[
                    const UiText('Birth time unknown · General guidance only'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                BirthForm(session: session, onboarding: true),
                          ),
                        ),
                        child: const UiText('Add birth time'),
                      ),
                    ),
                  ],
                  Text(
                    ex(
                      context,
                      known
                          ? 'Open each chapter for a short reading of your saved birth chart.'
                          : 'Open each chapter for general reflections, without timed chart predictions.',
                      known
                          ? 'உங்கள் பிறப்பு ஜாதகத்தின் சுருக்கமான வாசிப்புக்கு ஒவ்வொரு பகுதியையும் திறக்கவும்.'
                          : 'காலப் பலன் கணிப்புகள் இல்லாத பொதுவான வழிகாட்டலுக்கு ஒவ்வொரு பகுதியையும் திறக்கவும்.',
                    ),
                  ),
                  reading(
                    ex(context, 'Personality & strengths', 'இயல்பும் பலமும்'),
                    'Daily',
                    known
                        ? 'Read my personality and strengths from my Moon, ascendant and birth star. Explain the strongest supported chart finding.'
                        : 'Help me reflect on my strengths. Ask one useful question about what I enjoy or do well.',
                  ),
                  reading(
                    ex(context, 'Work & talents', 'வேலையும் திறமைகளும்'),
                    'Career',
                    known
                        ? 'Read my natural talents and work style from my birth chart. Focus on natal placements rather than future dates.'
                        : 'Help me explore my work and talents. Ask one useful question about my interests or experience.',
                  ),
                  reading(
                    ex(context, 'Relationships', 'உறவுகள்'),
                    'Relationships',
                    known
                        ? 'Read my relationship and communication patterns from my birth chart, focusing on my own nature.'
                        : 'Help me reflect on how I communicate in relationships. Ask one useful question about my situation.',
                  ),
                  reading(
                    ex(context, 'Inner growth', 'மன வளர்ச்சி'),
                    'Spiritual',
                    known
                        ? 'Read the themes of inner growth and reflection in my birth chart. Use a specific verified chart placement.'
                        : 'Help me reflect on personal growth. Ask one useful question about what I want to improve.',
                  ),
                ],
              ],
              if (busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          );
        },
      ),
    );
  }
}

class ReadingPanel extends StatefulWidget {
  const ReadingPanel({
    super.key,
    required this.session,
    required this.title,
    required this.topic,
    required this.question,
    required this.language,
  });
  final ProfileSession session;
  final String title, topic, question, language;
  @override
  State<ReadingPanel> createState() => _ReadingPanelState();
}

class _ReadingPanelState extends State<ReadingPanel> {
  bool busy = false;
  String? error;
  String get keyName => 'explore:${widget.language}:${widget.question}';
  Future<void> read() async {
    if (busy || !publicChatEnabled) return;
    userJourney.event(
      'explore.reading',
      metadata: {'feature': 'explore', 'outcome': 'started'},
    );
    final s = widget.session,
        rev = s.revision,
        target = s.conversation(keyName),
        lang = widget.language;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await s.ask(
        category: widget.topic,
        question: widget.question,
        responseStyle: lang == 'ta' ? 'tamil' : 'english',
      );
      if (s.revision == rev) {
        final recorded = await s.recordGuidanceResponse(r, target, lang);
        userJourney.event(
          'explore.reading',
          metadata: {
            'feature': 'explore',
            'outcome': recorded ? 'success' : 'unavailable',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        userJourney.event(
          'explore.reading',
          metadata: {
            'feature': 'explore',
            'outcome': 'failed',
            'error': 'unknown',
          },
        );
        setState(
          () => error = ex(
            context,
            'Reading not confirmed. Tap again to retry the same request.',
            'வாசிப்பு உறுதியாகவில்லை. அதே கோரிக்கையை மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final answers = widget.session
        .conversation(keyName)
        .messages
        .where((m) => !m.fromUser)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (answers.isNotEmpty)
              Text(answers.last.text)
            else if (!publicChatEnabled)
              Text(
                ex(
                  context,
                  'Readings are temporarily unavailable. Please try again later.',
                  'வாசிப்புகள் தற்போது கிடைக்கவில்லை. சிறிது நேரத்தில் மீண்டும் முயற்சிக்கவும்.',
                ),
              )
            else
              FilledButton.tonal(
                onPressed: busy ? null : read,
                child: Text(
                  busy
                      ? ex(
                          context,
                          'Preparing your reading…',
                          'வாசிப்பு தயாராகிறது…',
                        )
                      : ex(context, 'Open reading', 'வாசிப்பைத் திறக்க'),
                ),
              ),
            if (error != null) Text(error!),
          ],
        ),
      ),
    );
  }
}
