import 'bronze_theme.dart';
import 'matching_art.dart';
import 'notification_center.dart';
import 'rasi_emblem.dart';
import 'cinematic_matching.dart';
import 'services/matching_rasi.dart';
import 'location_search_sheet.dart';
import 'services/name_display.dart';
import 'services/remote_config.dart';
import 'payment_support.dart' show walletMode;
import 'launch_intro.dart';
import 'coin_wallet.dart';
import 'services/ui_language.dart';
import 'services/user_journey.dart';
import 'daily_timing_data.dart';
import 'daily_timing_guide.dart';
import 'saved_profile_actions.dart';

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'main.dart'
    show
        phoneAccess,
        accountStorage,
        testerAccess,
        profileSession,
        bodyInk,
        muted,
        MainTabScope;
import 'birth_form.dart';
import 'south_chart.dart';
import 'services/jyotara_api.dart';
import 'services/profile_session.dart';
import 'services/profile_gender.dart';
import 'services/local_profile_vault.dart';

part 'daily_rhythm.dart';
part 'matching_studio.dart';
part 'matching_entry.dart';

const zodiacNames = [
  'Mesha · Aries',
  'Vrishabha · Taurus',
  'Mithuna · Gemini',
  'Karka · Cancer',
  'Simha · Leo',
  'Kanya · Virgo',
  'Tula · Libra',
  'Vrischika · Scorpio',
  'Dhanu · Sagittarius',
  'Makara · Capricorn',
  'Kumbha · Aquarius',
  'Meena · Pisces',
];
const zodiacIds = [
  'aries',
  'taurus',
  'gemini',
  'cancer',
  'leo',
  'virgo',
  'libra',
  'scorpio',
  'sagittarius',
  'capricorn',
  'aquarius',
  'pisces',
];
String readingLanguage(BuildContext context) =>
    context
            .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
            ?.notifier
            ?.value ==
        'ta'
    ? 'ta'
    : 'en';

String readingText(BuildContext context, String value) =>
    readingLanguage(context) == 'ta' ? tamilUi[value] ?? value : value;

String zodiacLabel(BuildContext context, int index) =>
    uiText(context, zodiacNames[index]);

Future<Map<String, dynamic>> discoveryRequest(
  String path,
  Map<String, dynamic> body, {
  http.Client? client,
}) async {
  try {
    if (coinWalletEnabled && path == '/api/kundli/matching') {
      body = await confirmCoins('matching', body);
    }
    final response = await (client?.post ?? http.post)(
      Uri.parse(defaultApiBaseUrl).resolve(path),
      headers: {
        'Content-Type': 'application/json',
        if (minuteBillingEnabled) 'X-Jyotara-Wallet-Catalog': '2',
        if (coinWalletEnabled && path == '/api/kundli/matching')
          'X-Jyotara-Wallet-Mode': walletMode,
        if (const bool.fromEnvironment('JYOTARA_REQUIRE_PHONE_AUTH'))
          'X-Jyotara-Phone-Auth': 'required',
        'X-Jyotara-Tester-Code': testerAccess.code ?? '',
        if (phoneAccess.token != null)
          'Authorization': 'Bearer ${phoneAccess.token}',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 90));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Please try again later.');
    }
    return data;
  } on http.ClientException {
    throw Exception(
      'Unable to connect. Check your internet connection, then tap Retry.',
    );
  } on TimeoutException {
    throw Exception(
      'The reading is taking longer than expected. Please try again shortly.',
    );
  } on FormatException {
    throw Exception(
      'The reading could not be loaded. Please try again shortly.',
    );
  }
}

class DiscoveryActions extends StatelessWidget {
  const DiscoveryActions({super.key, this.editorial = false});
  final bool editorial;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!editorial)
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const UiText('Wallet · ₹0  +'),
          ),
        ),
      if (!editorial) const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item
              in [
                (
                  Icons.wb_sunny_outlined,
                  'Daily\nHoroscope',
                  const FeatureGate(
                    feature: 'daily',
                    child: DailyHoroscopeScreen(),
                  ),
                ),
                (
                  Icons.grid_on_rounded,
                  'Free\nKundli',
                  const KundliLibraryScreen(),
                ),
                (
                  Icons.favorite_border,
                  editorial ? 'Matching' : 'Birth Chart\nMatching',
                  const FeatureGate(
                    feature: 'matching',
                    child: MatchingScreen(),
                  ),
                ),
              ].where(
                (item) => item.$1 == Icons.wb_sunny_outlined
                    ? RemoteConfigScope.watch(context).enabled('daily')
                    : item.$1 == Icons.favorite_border
                    ? RemoteConfigScope.watch(context).enabled('matching')
                    : true,
              ))
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => item.$3),
                ),
                child: Container(
                  constraints: editorial
                      ? const BoxConstraints(minHeight: 140)
                      : null,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: editorial ? 20 : 18,
                  ),
                  decoration: BoxDecoration(
                    color: BronzePalette.card,
                    borderRadius: BorderRadius.circular(editorial ? 12 : 20),
                    border: editorial
                        ? null
                        : Border.all(color: BronzePalette.border),
                  ),
                  child: Column(
                    children: [
                      if (editorial)
                        SizedBox(
                          height: 48,
                          child: CustomPaint(
                            size: const Size(44, 44),
                            painter: _HomeToolPainter(item.$1),
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: BronzePalette.raised,
                          child: Icon(
                            item.$1,
                            color: BronzePalette.accent,
                            size: 28,
                          ),
                        ),
                      const SizedBox(height: 10),
                      UiText(
                        item.$2,
                        textAlign: TextAlign.center,
                        style: editorial
                            ? const TextStyle(fontSize: 12, height: 1.35)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class _HomeToolPainter extends CustomPainter {
  const _HomeToolPainter(this.icon);
  final IconData icon;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = BronzePalette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final c = Offset(size.width / 2, size.height / 2);
    if (icon == Icons.favorite_border) {
      final heart = Path()
        ..moveTo(c.dx, c.dy + 17)
        ..cubicTo(c.dx - 32, c.dy - 3, c.dx - 17, c.dy - 26, c.dx, c.dy - 11)
        ..cubicTo(c.dx + 17, c.dy - 26, c.dx + 32, c.dy - 3, c.dx, c.dy + 17);
      canvas.drawPath(heart, p);
    } else if (icon == Icons.grid_on_rounded) {
      for (final dx in [-17.0, 2.0]) {
        for (final dy in [-17.0, 2.0]) {
          final rect = Rect.fromLTWH(c.dx + dx, c.dy + dy, 15, 15);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFFFFD88C), Color(0xFFAF7428)],
              ).createShader(rect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            p,
          );
        }
      }
    } else {
      canvas.drawCircle(c, 11, p);
      for (var i = 0; i < 12; i++) {
        final angle = i * pi / 6;
        final direction = Offset(cos(angle), sin(angle));
        canvas.drawLine(c + direction * 16, c + direction * 21, p);
      }
    }
  }

  @override
  bool shouldRepaint(_HomeToolPainter old) => icon != old.icon;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int selected = 100;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('Wallet')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const UiText('Your balance', style: TextStyle(color: muted)),
        const UiText(
          '₹0',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const UiText('Wallet preview', style: TextStyle(color: bodyInk)),
        const UiText(
          'Choose a recharge amount to preview. Payments and deductions are not enabled during this test.',
        ),
        const SizedBox(height: 28),
        const UiText(
          'Add money',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final amount in [50, 100, 200, 500, 1000, 2000, 3000, 4000])
                SizedBox(
                  width: (c.maxWidth - 24) / 3,
                  child: OutlinedButton(
                    onPressed: () => setState(() => selected = amount),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      backgroundColor: selected == amount
                          ? BronzePalette.raised
                          : null,
                      side: BorderSide(
                        color: selected == amount ? bodyInk : muted,
                      ),
                    ),
                    child: UiText('₹$amount'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        UiText('Selected recharge: ₹$selected'),
        const SizedBox(height: 12),
        const FilledButton(
          onPressed: null,
          child: UiText('Payments coming later'),
        ),
        const SizedBox(height: 24),
        const UiText(
          'Transaction history',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const UiText('No transactions yet.'),
      ],
    ),
  );
}

class DailyHoroscopeScreen extends StatefulWidget {
  const DailyHoroscopeScreen({
    super.key,
    this.request = discoveryRequest,
    this.readCity,
    this.writeCity,
    this.pickCity,
  });
  final Future<String?> Function()? readCity;
  final Future<void> Function(String)? writeCity;
  final Future<List<dynamic>?> Function(BuildContext, String)? pickCity;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  request;
  @override
  State<DailyHoroscopeScreen> createState() => _DailyHoroscopeScreenState();
}

String dailyShortText(String value) {
  final sentences = value.trim().split(RegExp(r'(?<=[.!?。])\s+'));
  return sentences.first;
}

// Preserve provider wording while separating complete thoughts into short reading points.
List<String> dailyReadingPoints(String value) => value
    .trim()
    .split(RegExp(r'(?<=[.!?。])\s+|\n+'))
    .where((part) => part.trim().isNotEmpty)
    .map((part) => part.trim())
    .toList();

// Topic labels describe source content, not a new prediction or a rating.
String dailyTheme(Map<String, dynamic> reading, bool tamil) {
  final text = (reading['sections'] as List? ?? [])
      .map((e) => e['text'])
      .join(' ')
      .toLowerCase();
  for (final topic in [
    (
      ['communicat', 'conversation', 'பேச்சு', 'உரையாட'],
      'Communication',
      'உரையாடல்',
    ),
    (['family', 'குடும்ப'], 'Family', 'குடும்பம்'),
    (['plan', 'திட்ட'], 'Planning', 'திட்டமிடல்'),
    (['patien', 'பொறும'], 'Patience', 'பொறுமை'),
    (['creativ', 'படைப்ப'], 'Creativity', 'படைப்பாற்றல்'),
    (['work', 'career', 'வேலை', 'தொழில்'], 'Work', 'வேலை'),
    (['relationship', 'உறவு'], 'Relationships', 'உறவுகள்'),
  ]) {
    if (topic.$1.any(text.contains)) return tamil ? topic.$3 : topic.$2;
  }
  return tamil ? 'இன்றைய பலன்' : 'Daily reading';
}

class _DailyHoroscopeScreenState extends State<DailyHoroscopeScreen> {
  void updateDaily(VoidCallback action) => setState(action);

  int sign = 0, day = 0, revision = 0, calendarRevision = 0, energyTab = 0;
  final scroll = ScrollController();
  String? profileRasi;
  String? language, error, calendarError, city;
  double? latitude, longitude;
  bool busy = false, calendarBusy = false;
  late final Future<void> cityRestoration;
  Future<void>? readingLoad, calendarLoad;
  String? readingRequestDate, calendarRequestDate;
  final readings = <int, Map<String, dynamic>>{};
  Map<String, dynamic>? calendar;
  String local(String en, String ta) =>
      readingLanguage(context) == 'ta' ? ta : en;
  String get date => DateTime.now()
      .toUtc()
      .add(Duration(hours: 5, minutes: 30, days: day))
      .toIso8601String()
      .substring(0, 10);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !MainTabScope.contains(context) &&
          ModalRoute.of(context)?.isCurrent != false) {
        userJourney.screen('daily');
      }
    });
    final initial = SouthIndianChart.signIndex(profileSession.facts?['rashi']);
    sign = initial < 0 ? 0 : initial;
    profileRasi = profileSession.facts?['rashi']?.toString();
    profileSession.addListener(profileChanged);
    cityRestoration = _restoreCity();
  }

  void profileChanged() {
    final next = profileSession.facts?['rashi']?.toString();
    if (!mounted) return;
    if (next == profileRasi) {
      setState(() {});
      return;
    }
    profileRasi = next;
    final index = SouthIndianChart.signIndex(next);
    setState(() => sign = index < 0 ? 0 : index);
    _load();
  }

  int _cityRevision = 0;
  Future<void> _citySave = Future.value();

  Future<void> _restoreCity() async {
    final revision = _cityRevision;
    try {
      final saved =
          await (widget.readCity?.call() ??
              SharedPreferencesAsync().getString('jyotara.daily.city.v1'));
      if (saved == null || !mounted || revision != _cityRevision) return;
      final v = jsonDecode(saved) as Map;
      setState(() {
        city = v['name'];
        latitude = (v['lat'] as num).toDouble();
        longitude = (v['lon'] as num).toDouble();
      });
      _loadCalendar();
    } catch (_) {
      /* A city can be selected again if preferences are unavailable. */
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = readingLanguage(context);
    if (language != next) {
      language = next;
      _load();
      _loadCalendar();
    }
  }

  @override
  void dispose() {
    revision++;
    calendarRevision++;
    profileSession.removeListener(profileChanged);
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() => readingLoad = _loadReading();

  Future<void> selectedTimingSourcesReady() async {
    await cityRestoration;
    while (mounted) {
      final selectedReading = readingLoad, selectedCalendar = calendarLoad;
      await Future.wait<void>([?selectedReading, ?selectedCalendar]);
      if (!mounted) return;
      // Profile, language, city or date changes can replace either request.
      // Only snapshot once both currently selected requests have settled.
      if (selectedReading != readingLoad || selectedCalendar != calendarLoad) {
        continue;
      }
      if (readingRequestDate != date || calendarRequestDate != date) {
        _load();
        _loadCalendar();
        continue;
      }
      return;
    }
  }

  Future<void> _loadReading() async {
    final rev = ++revision, selected = sign;
    final requestedDate = date, requestedLanguage = language;
    readingRequestDate = requestedDate;
    setState(() {
      busy = true;
      error = null;
      readings.clear();
    });
    Future<void> fetch(int i) async {
      try {
        final value = await widget.request('/api/horoscope/daily', {
          'sign': zodiacIds[i],
          'date': requestedDate,
          'language': i == selected ? requestedLanguage : 'en',
        });
        if (mounted &&
            rev == revision &&
            readings[i]?['_displayLanguage'] != requestedLanguage) {
          value['_displayLanguage'] = i == selected ? requestedLanguage : 'en';
          setState(() => readings[i] = value);
        }
      } catch (_) {
        if (mounted && rev == revision && i == selected) {
          setState(
            () => error = local(
              'Reading unavailable. Please retry.',
              'பலன் கிடைக்கவில்லை. மீண்டும் முயற்சிக்கவும்.',
            ),
          );
        }
      }
    }

    await fetch(selected);
    if (!mounted || rev != revision) return;
    setState(() => busy = false);
  }

  Future<void> selectSign(int i) async {
    setState(() {
      sign = i;
      error = null;
      busy = false;
    });
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    if (readings[i]?['_displayLanguage'] == language) return;
    final rev = revision;
    final requestedLanguage = language;
    setState(() => busy = true);
    try {
      final value = await widget.request('/api/horoscope/daily', {
        'sign': zodiacIds[i],
        'date': date,
        'language': requestedLanguage,
      });
      if (mounted && rev == revision) {
        value['_displayLanguage'] = requestedLanguage;
        setState(() => readings[i] = value);
      }
    } catch (_) {
      if (mounted && rev == revision && sign == i) {
        setState(
          () => error = local(
            'Reading unavailable. Please retry.',
            'பலன் கிடைக்கவில்லை. மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      if (mounted && rev == revision && sign == i) setState(() => busy = false);
    }
  }

  Future<void> _loadCalendar() => calendarLoad = _loadCalendarData();

  Future<void> _loadCalendarData() async {
    final rev = ++calendarRevision;
    final requestedDate = date;
    calendarRequestDate = requestedDate;
    setState(() {
      calendar = null;
      calendarError = null;
      calendarBusy = city != null;
    });
    if (city == null) return;
    try {
      final v = await widget.request('/api/explore/panchang', {
        'date': requestedDate,
        'latitude': latitude,
        'longitude': longitude,
        'language': 'en',
      });
      if (mounted && rev == calendarRevision) setState(() => calendar = v);
    } catch (_) {
      if (mounted && rev == calendarRevision) {
        setState(
          () => calendarError = local(
            'Timings unavailable',
            'நேரங்கள் கிடைக்கவில்லை',
          ),
        );
      }
    } finally {
      if (mounted && rev == calendarRevision) {
        setState(() => calendarBusy = false);
      }
    }
  }

  Future<void> _chooseCity() async {
    final chosen = await (widget.pickCity != null
        ? widget.pickCity!(context, city ?? '')
        : pickIndianLocation(
            context,
            profileSession,
            initialQuery: city ?? '',
            title: 'Current city',
          ));
    if (chosen == null || !mounted) return;
    _cityRevision++;
    setState(() {
      city = '${chosen[1]}, ${chosen[2]}';
      latitude = (chosen[6] as num).toDouble();
      longitude = (chosen[7] as num).toDouble();
    });
    _loadCalendar();
    final saved = jsonEncode({'name': city, 'lat': latitude, 'lon': longitude});
    _citySave = _citySave.then((_) async {
      try {
        await (widget.writeCity?.call(saved) ??
            SharedPreferencesAsync().setString('jyotara.daily.city.v1', saved));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                local(
                  'City could not be saved. Please select it again.',
                  'நகரத்தைச் சேமிக்க முடியவில்லை. மீண்டும் தேர்ந்தெடுக்கவும்.',
                ),
              ),
            ),
          );
        }
      }
    });
    await _citySave;
  }

  String time(dynamic value) {
    final v = DateTime.tryParse('$value')
        ?.toUtc()
        .add(const Duration(hours: 5, minutes: 30));
    return v == null
        ? '—'
        : '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  Widget heading(String en, String ta) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      local(en, ta),
      style: const TextStyle(
        fontSize: 22,
        fontFamily: 'JyotaraEditorial',
        color: BronzePalette.gold,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => _dailyLayout();
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard(this.title, this.text);
  final String title, text;
  @override
  Widget build(BuildContext context) => EntranceReveal(
    child: Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              readingText(context, title),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: bodyInk,
              ),
            ),
            const SizedBox(height: 10),
            UiText(readingText(context, text)),
          ],
        ),
      ),
    ),
  );
}

class SavedKundli {
  SavedKundli(this.id, this.session);
  final String id;
  final ProfileSession session;
}

class KundliLibrary {
  static const storage = FlutterSecureStorage();
  static String get indexKey => accountStorage.key('jyotara.kundli.index.v1');
  static Future<List<SavedKundli>> load() async {
    final raw = await storage.read(key: indexKey);
    final ids = raw == null
        ? <String>[]
        : (jsonDecode(raw) as List).cast<String>();
    final result = <SavedKundli>[];
    for (final id in ids) {
      if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
        throw const FormatException('Invalid saved birth chart');
      }
      final session = _session(id);
      await session.restore();
      result.add(SavedKundli(id, session));
    }
    return result;
  }

  static ProfileSession _session(String id) {
    final storageKey = accountStorage.key('jyotara.kundli.$id');
    return ProfileSession(
      api: JyotaraApiClient(
        testerCode: () => testerAccess.code,
        phoneToken: () => phoneAccess.token,
      ),
      vault: LocalProfileVault(
        read: () => storage.read(key: storageKey),
        write: (value) => accountStorage.writeKey(storageKey, value),
      ),
    );
  }

  static Future<SavedKundli> create(List<SavedKundli> rows) async {
    if (rows.length >= 10) {
      throw Exception(
        'You can save up to 10 birth charts. Remove one to add another.',
      );
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await accountStorage.writeKey(
      indexKey,
      jsonEncode([...rows.map((r) => r.id), id]),
    );
    return SavedKundli(id, _session(id));
  }

  static Future<void> remove(SavedKundli row, List<SavedKundli> rows) async {
    final originalIndexKey = indexKey;
    // A previous failed deletion is retryable. The session retains the server
    // capability and confirms storage again before the index is removed.
    if (row.session.facts == null) {
      await row.session.discardUnfinished();
    } else {
      await row.session.clear(includeServer: row.session.canDeleteServer);
    }
    if (row.session.storageError != null) {
      throw Exception(row.session.storageError);
    }
    await accountStorage.writeKey(
      originalIndexKey,
      jsonEncode(rows.where((r) => r.id != row.id).map((r) => r.id).toList()),
    );
  }
}

class KundliLibraryScreen extends StatefulWidget {
  const KundliLibraryScreen({
    super.key,
    this.includeOwnProfile = false,
    this.loadProfiles = KundliLibrary.load,
    this.removeProfile = KundliLibrary.remove,
  });
  final bool includeOwnProfile;
  final Future<List<SavedKundli>> Function() loadProfiles;
  final Future<void> Function(SavedKundli, List<SavedKundli>) removeProfile;
  @override
  State<KundliLibraryScreen> createState() => _KundliLibraryScreenState();
}

class _KundliLibraryScreenState extends State<KundliLibraryScreen> {
  List<SavedKundli> rows = [];
  String query = '';
  String? error;
  bool busy = true;
  bool libraryLoaded = false;
  bool _confirmingDeletion = false;
  String? _loadedIndexKey;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final targetKey = KundliLibrary.indexKey;
    try {
      final value = await widget.loadProfiles();
      if (mounted) {
        setState(() {
          rows = targetKey == KundliLibrary.indexKey ? value : [];
          libraryLoaded = targetKey == KundliLibrary.indexKey;
          _loadedIndexKey = libraryLoaded ? targetKey : null;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          libraryLoaded = false;
          error = 'Saved birth charts could not be opened. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          if (targetKey != KundliLibrary.indexKey) {
            rows = [];
            libraryLoaded = false;
            _loadedIndexKey = null;
            error = savedProfileText(
              context,
              'Account changed. Reopen saved profiles.',
              'கணக்கு மாறியுள்ளது. சேமித்த விவரங்களை மீண்டும் திறக்கவும்.',
            );
          }
        });
      }
    }
  }

  Future<void> _edit([SavedKundli? row]) async {
    if (busy || (row == null && !libraryLoaded)) return;
    setState(() => busy = true);
    try {
      final selected = row ?? await KundliLibrary.create(rows);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              BirthForm(session: selected.session, onboarding: true),
        ),
      );
      await selected.session.flushStorage();
      if (row == null &&
          selected.session.facts == null &&
          !selected.session.profileRequestUnconfirmed &&
          selected.session.storageError == null) {
        await KundliLibrary.remove(selected, [...rows, selected]);
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _remove(SavedKundli row) async {
    if (busy ||
        _confirmingDeletion ||
        !libraryLoaded ||
        row.id == 'personal' ||
        identical(row.session, profileSession)) {
      return;
    }
    final targetKey = _loadedIndexKey;
    if (targetKey != KundliLibrary.indexKey) {
      await _load();
      return;
    }
    if (row.session.calculating ||
        row.session.answering ||
        row.session.deleting) {
      setState(
        () => error = savedProfileText(
          context,
          'Please wait for this person’s current request to finish.',
          'இந்த நபரின் தற்போதைய கோரிக்கை முடியும் வரை காத்திருக்கவும்.',
        ),
      );
      return;
    }
    setState(() => _confirmingDeletion = true);
    try {
      final yes = await confirmSavedProfileDeletion(
        context,
        name: row.session.nickname,
      );
      if (!yes || !mounted || targetKey != KundliLibrary.indexKey) return;
      if (row.session.calculating ||
          row.session.answering ||
          row.session.deleting) {
        setState(
          () => error = savedProfileText(
            context,
            'Please wait for this person’s current request to finish.',
            'இந்த நபரின் தற்போதைய கோரிக்கை முடியும் வரை காத்திருக்கவும்.',
          ),
        );
        return;
      }
      setState(() => busy = true);
      await widget.removeProfile(row, rows);
      if (!mounted || targetKey != KundliLibrary.indexKey) return;
      await _load();
    } catch (_) {
      if (mounted && targetKey == KundliLibrary.indexKey) {
        setState(
          () => error = savedProfileText(
            context,
            'This person could not be deleted. Please retry.',
            'இந்த நபரின் விவரங்களை நீக்க முடியவில்லை. மீண்டும் முயலுங்கள்.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          _confirmingDeletion = false;
          if (targetKey != KundliLibrary.indexKey) {
            rows = [];
            libraryLoaded = false;
            _loadedIndexKey = null;
            error = savedProfileText(
              context,
              'Account changed. Reopen saved profiles.',
              'கணக்கு மாறியுள்ளது. சேமித்த விவரங்களை மீண்டும் திறக்கவும்.',
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: UiText(
        widget.includeOwnProfile ? 'My Profiles' : 'Free Birth Chart',
      ),
    ),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        if (widget.includeOwnProfile)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(profileSession.nickname),
              subtitle: Text(
                '${uiText(context, profileSession.facts?['rashi'] as String? ?? 'Unavailable')} · ${profileSession.birthInput?.indiaDateTime.toString().substring(0, 10) ?? ''}\n${profileSession.birthplaceLabel ?? ''}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      BirthForm(session: profileSession, onboarding: true),
                ),
              ),
            ),
          ),
        const UiText(
          'Charts for the people you know',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const UiText(
          'Save up to 10 separate birth charts with permission. Your own chat profile stays separate. Up to 10 new chart sessions per tester per day.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: uiText(context, 'Search birth chart by name'),
          ),
        ),
        const SizedBox(height: 20),
        if (busy) const LinearProgressIndicator(),
        if (error != null) ...[
          UiText(error!),
          TextButton(
            onPressed: busy ? null : _load,
            child: const UiText('Retry loading birth charts'),
          ),
        ],
        if (!busy && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: UiText('Your saved birth charts will appear here.'),
          ),
        for (final row in rows.where(
          (r) => r.session.nickname.toLowerCase().contains(query.toLowerCase()),
        ))
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                ListTile(
                  key: ValueKey('library-profile-${row.id}'),
                  title: UiText(
                    row.session.nickname.isEmpty
                        ? 'Unfinished Birth Chart'
                        : row.session.nickname,
                  ),
                  subtitle: UiText(
                    '${row.session.birthInput?.indiaDateTime.toString().substring(0, 10) ?? uiText(context, 'Add birth details')}\n${row.session.birthplaceLabel ?? uiText(context, 'Birthplace not saved')}',
                  ),
                  isThreeLine: true,
                  onTap: busy
                      ? null
                      : () => row.session.facts == null
                            ? _edit(row)
                            : Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      title: UiText(row.session.nickname),
                                    ),
                                    body: ListView(
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        20,
                                        20,
                                        20 +
                                            MediaQuery.viewPaddingOf(context)
                                                .bottom,
                                      ),
                                      children: [
                                        SouthIndianChart(
                                          facts: row.session.facts!,
                                        ),
                                        const SizedBox(height: 16),
                                        UiText(
                                          row.session.birthTimeKnown
                                              ? 'Calculated from the saved birth details.'
                                              : 'Birth time is unknown. Time-sensitive chart details are limited.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  trailing: IconButton(
                    tooltip: uiText(context, 'Edit birth chart'),
                    onPressed: busy ? null : () => _edit(row),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SavedProfileDeleteButton(
                      key: ValueKey('library-delete-profile-${row.id}'),
                      name: row.session.nickname,
                      onPressed: busy ? null : () => _remove(row),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy || !libraryLoaded ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const UiText('Create New Birth Chart'),
        ),
      ],
    ),
  );
}

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({
    super.key,
    this.request = discoveryRequest,
    this.loadKundlis = KundliLibrary.load,
    this.resolveRasi = resolveMatchingPersonRasi,
    this.createKundli = KundliLibrary.create,
    this.removeKundli = KundliLibrary.remove,
  });
  final Future<SavedKundli> Function(List<SavedKundli>) createKundli;
  final Future<void> Function(SavedKundli, List<SavedKundli>) removeKundli;
  final Future<String?> Function(Map<String, dynamic>) resolveRasi;
  final Future<List<SavedKundli>> Function() loadKundlis;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  request;
  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

Future<String?> resolveMatchingPersonRasi(Map<String, dynamic> person) =>
    loadMatchingRasi(
      person,
      phoneToken: () => phoneAccess.token,
      testerCode: () => testerAccess.code,
    );

class _MatchingScreenState extends State<MatchingScreen> {
  List<SavedKundli> rows = [];
  SavedKundli? boy, girl;
  Map<String, dynamic>? boyDraft, girlDraft;
  final Set<String> _pendingRasi = {};
  bool consent = false, busy = false;
  bool _removingPerson = false;
  Completer<void>? _draftRemoval;
  String? _loadedPeopleKey;
  int _loadRevision = 0;
  String connectionType = 'My Crush';
  List<Map<String, dynamic>> people = [];
  String get peopleKey => accountStorage.key('jyotara.matching.people.v1');
  String? error;
  Map<String, dynamic>? result;
  void _selectContext(String value) => setState(() => connectionType = value);
  void _selectConsent(bool? value) => setState(() => consent = value ?? false);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        userJourney.screen('matching');
      }
    });
    _load();
  }

  Future<void> _load() async {
    final targetKey = peopleKey;
    final loadRevision = ++_loadRevision;
    try {
      final saved = await widget.loadKundlis();
      final savedPeople = await KundliLibrary.storage.read(key: targetKey);
      if (mounted && targetKey == peopleKey && loadRevision == _loadRevision) {
        setState(() {
          _loadedPeopleKey = targetKey;
          people = savedPeople == null
              ? []
              : (jsonDecode(savedPeople) as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
          rows = [
            if (profileSession.facts != null)
              SavedKundli('personal', profileSession),
            ...saved.where((r) => r.session.birthInput != null),
          ];
          boy = rows.where((r) => r.id == boy?.id).firstOrNull;
          girl = rows.where((r) => r.id == girl?.id).firstOrNull;
          result = null;
        });
      }
    } catch (_) {
      if (mounted && targetKey == peopleKey && loadRevision == _loadRevision) {
        setState(() => error = 'Could not open saved birth charts.');
      }
    }
  }

  bool _ensureMatchingOwner() {
    if (_loadedPeopleKey == peopleKey) return true;
    if (!mounted) return false;
    setState(() {
      _loadedPeopleKey = null;
      rows = [];
      people = [];
      boy = null;
      girl = null;
      boyDraft = null;
      girlDraft = null;
      consent = false;
      result = null;
      error = null;
    });
    unawaited(_load());
    return false;
  }

  Map<String, dynamic> _input(SavedKundli row) {
    final b = row.session.birthInput!;
    return {
      'datetime': '${b.indiaDateTime.toIso8601String().substring(0, 19)}+05:30',
      'latitude': b.latitude,
      'longitude': b.longitude,
      'exactTime': b.exactTime,
      'nickname': row.session.nickname,
      'birthplaceLabel': row.session.birthplaceLabel,
    };
  }

  String local(String en, String ta) =>
      readingLanguage(context) == 'ta' ? ta : en;
  Map<String, dynamic>? details(bool male) =>
      (male ? boyDraft : girlDraft) ??
      ((male ? boy : girl)?.session.birthInput == null
          ? null
          : _input((male ? boy : girl)!));

  String? _rasi(bool first) {
    final draft = first ? boyDraft : girlDraft;
    if (draft != null) {
      return draft['rasiBirthKey'] == matchingBirthKey(draft)
          ? draft['calculatedRasi'] as String?
          : null;
    }
    final row = first ? boy : girl;
    return row?.session.facts?['rashi'] as String?;
  }

  Future<void> _resolveRasi(Map<String, dynamic> person) async {
    if (!mounted || !_ensureMatchingOwner()) return;
    final key = matchingBirthKey(person);
    if (person['rasiBirthKey'] == key &&
        SouthIndianChart.signIndex(person['calculatedRasi']) >= 0) {
      return;
    }
    if (!_pendingRasi.add(key)) return;
    if (mounted) setState(() {});
    final storageKey = peopleKey;
    final owner = accountStorage.account;
    try {
      final rasi = await widget.resolveRasi(Map<String, dynamic>.from(person));
      // Merge only after a confirmed local removal publishes its final state.
      // This prevents another person's late enrichment from restoring it.
      while (_draftRemoval != null) {
        await _draftRemoval!.future;
      }
      if (!mounted ||
          storageKey != peopleKey ||
          accountStorage.account != owner ||
          SouthIndianChart.signIndex(rasi) < 0) {
        return;
      }
      Map<String, dynamic> updated(Map<String, dynamic> data) =>
          matchingBirthKey(data) == key
          ? {...data, 'calculatedRasi': rasi, 'rasiBirthKey': key}
          : data;
      final next = people.map(updated).toList();
      // Publish the merged state before queuing persistence. A second chart
      // finishing concurrently must merge with this result, not overwrite it.
      setState(() {
        people = next;
        if (boyDraft != null) boyDraft = updated(boyDraft!);
        if (girlDraft != null) girlDraft = updated(girlDraft!);
      });
      await accountStorage.writeKey(storageKey, jsonEncode(next));
    } catch (_) {
      // Rasi is optional: comparison still uses original birth inputs. No
      // guessed sign or repeated automatic provider request on failure.
    } finally {
      _pendingRasi.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> choosePerson(bool male) async {
    if (busy || _removingPerson || !_ensureMatchingOwner()) return;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                local('Choose a person', 'ஒருவரைத் தேர்வுசெய்க'),
                style: const TextStyle(
                  fontSize: 24,
                  fontFamily: 'JyotaraEditorial',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(local('Add new person', 'புதியவரைச் சேர்க்கவும்')),
                onTap: () => Navigator.pop(context, 'new'),
              ),
              if (details(male) != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(
                    local(
                      'Edit selected details',
                      'தேர்ந்தெடுத்த விவரங்களை மாற்றவும்',
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              for (final row in rows)
                ListTile(
                  key: ValueKey('matching-saved-${row.id}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(row.session.nickname),
                  subtitle: Text(
                    '${row.session.birthplaceLabel ?? ''} · ${row.session.birthInput!.indiaDateTime.year}',
                  ),
                  onTap: (male ? girl : boy)?.id == row.id
                      ? null
                      : () => Navigator.pop(context, row),
                  trailing:
                      row.id == 'personal' ||
                          identical(row.session, profileSession)
                      ? null
                      : TextButton.icon(
                          key: ValueKey('matching-delete-${row.id}'),
                          icon: const Icon(Icons.delete_outline, size: 19),
                          label: Text(local('Delete', 'நீக்கு')),
                          onPressed: _removingPerson
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await _removeSavedPerson(row);
                                },
                        ),
                ),
              for (final person in people)
                ListTile(
                  key: ValueKey('matching-local-${matchingBirthKey(person)}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text('${person['nickname']}'),
                  subtitle: Text('${person['birthplaceLabel'] ?? ''}'),
                  onTap: () => Navigator.pop(context, person),
                  trailing: TextButton.icon(
                    key: ValueKey(
                      'matching-delete-local-${matchingBirthKey(person)}',
                    ),
                    icon: const Icon(Icons.delete_outline, size: 19),
                    label: Text(local('Delete', 'நீக்கு')),
                    onPressed: _removingPerson
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _removeDraftPerson(person);
                          },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !_ensureMatchingOwner() || choice == null) return;
    if (choice == 'new' || choice == 'edit') {
      await _enterBirth(male, fresh: choice == 'new');
      return;
    }
    setState(() {
      if (male) {
        boy = choice is SavedKundli ? choice : null;
        boyDraft = choice is Map<String, dynamic> ? choice : null;
      } else {
        girl = choice is SavedKundli ? choice : null;
        girlDraft = choice is Map<String, dynamic> ? choice : null;
      }
      consent = false;
      error = null;
      result = null;
    });
    if (choice is Map<String, dynamic>) unawaited(_resolveRasi(choice));
  }

  bool _samePerson(Map<String, dynamic> a, Map<String, dynamic> b) =>
      matchingBirthKey(a) == matchingBirthKey(b) &&
      a['nickname'] == b['nickname'];

  Future<void> _removeSavedPerson(SavedKundli row) async {
    if (busy ||
        _removingPerson ||
        row.id == 'personal' ||
        identical(row.session, profileSession) ||
        !_ensureMatchingOwner()) {
      return;
    }
    setState(() => _removingPerson = true);
    try {
      final targetKey = _loadedPeopleKey!;
      if (row.session.calculating ||
          row.session.answering ||
          row.session.deleting) {
        await _notice(
          local(
            'Please wait for this person’s current request to finish before deleting.',
            'இந்த நபரின் தற்போதைய கோரிக்கை முடிந்தபின் நீக்குங்கள்.',
          ),
        );
        return;
      }
      final confirmed = await confirmSavedProfileDeletion(
        context,
        name: row.session.nickname,
        tamil: readingLanguage(context) == 'ta',
        includesServer: row.session.canDeleteServer,
      );
      if (!mounted ||
          !_ensureMatchingOwner() ||
          targetKey != peopleKey ||
          !confirmed) {
        return;
      }
      if (row.session.calculating ||
          row.session.answering ||
          row.session.deleting) {
        await _notice(
          local(
            'Please wait for this person’s current request to finish before deleting.',
            'இந்த நபரின் தற்போதைய கோரிக்கை முடிந்தபின் நீக்குங்கள்.',
          ),
        );
        return;
      }
      userJourney.event(
        'matching.delete',
        metadata: {'feature': 'matching', 'outcome': 'started'},
      );
      try {
        await widget.removeKundli(
          row,
          rows.where((r) => r.id != 'personal').toList(),
        );
        if (!mounted || !_ensureMatchingOwner() || targetKey != peopleKey) {
          return;
        }
        userJourney.event(
          'matching.delete',
          metadata: {'feature': 'matching', 'outcome': 'success'},
        );
        setState(() {
          if (boy?.id == row.id) boy = null;
          if (girl?.id == row.id) girl = null;
          consent = false;
          result = null;
          error = null;
        });
        await _load();
      } catch (_) {
        if (mounted && targetKey == peopleKey) {
          userJourney.event(
            'matching.delete',
            metadata: {
              'feature': 'matching',
              'outcome': 'failed',
              'error': 'unknown',
            },
          );
          await _notice(
            local(
              'Could not delete the saved person. Please retry.',
              'சேமித்தவரை நீக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        _ensureMatchingOwner();
        setState(() => _removingPerson = false);
      }
    }
  }

  Future<void> _removeDraftPerson(Map<String, dynamic> person) async {
    if (busy || _removingPerson || !_ensureMatchingOwner()) return;
    setState(() => _removingPerson = true);
    final targetKey = _loadedPeopleKey!;
    try {
      final confirmed = await confirmSavedProfileDeletion(
        context,
        name: '${person['nickname'] ?? ''}',
        tamil: readingLanguage(context) == 'ta',
        includesServer: false,
      );
      if (!mounted ||
          !_ensureMatchingOwner() ||
          targetKey != peopleKey ||
          !confirmed) {
        return;
      }
      userJourney.event(
        'matching.delete',
        metadata: {'feature': 'matching', 'outcome': 'started'},
      );
      final updated = people.where((p) => !_samePerson(p, person)).toList();
      _draftRemoval = Completer<void>();
      await accountStorage.writeKey(targetKey, jsonEncode(updated));
      if (!mounted || !_ensureMatchingOwner() || targetKey != peopleKey) return;
      userJourney.event(
        'matching.delete',
        metadata: {'feature': 'matching', 'outcome': 'success'},
      );
      setState(() {
        people = updated;
        if (boyDraft != null && _samePerson(boyDraft!, person)) boyDraft = null;
        if (girlDraft != null && _samePerson(girlDraft!, person)) {
          girlDraft = null;
        }
        consent = false;
        result = null;
        error = null;
      });
    } catch (_) {
      if (mounted && targetKey == peopleKey) {
        userJourney.event(
          'matching.delete',
          metadata: {
            'feature': 'matching',
            'outcome': 'failed',
            'error': 'storage',
          },
        );
        await _notice(
          local(
            'Could not delete the saved person. Please retry.',
            'சேமித்தவரை நீக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      _draftRemoval?.complete();
      _draftRemoval = null;
      if (mounted) {
        _ensureMatchingOwner();
        setState(() => _removingPerson = false);
      }
    }
  }

  Future<void> openReport(Map<String, dynamic> value) => Navigator.push(
    context,
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'matching_result'),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 650),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => MatchingResultScreen(value: value),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    ),
  );
  Future<void> openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SavedMatchesScreen()),
    );
  }

  Future<void> _notice(String message) async {
    setState(() => error = message);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UiText('Check matching details'),
        content: UiText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UiText('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _enterBirth(bool male, {bool fresh = false}) async {
    final targetKey = peopleKey;
    final previous = fresh
        ? null
        : male
        ? boy
        : girl;
    final draft = fresh
        ? null
        : male
        ? boyDraft
        : girlDraft;
    final savedRows = rows.where((r) => r.id != 'personal').toList();
    SavedKundli? selected;
    var keepCreatedSession = false;
    if (previous == null) {
      userJourney.event(
        'matching.add',
        metadata: {'feature': 'matching', 'outcome': 'started'},
      );
    }
    try {
      selected = previous ?? await widget.createKundli(savedRows);
      if (!mounted || targetKey != peopleKey) return;
      // Legacy matching-only entries use the shared saved-chart form too. Keep
      // their place label while upgrading to a calculated, separate chart.
      if (draft != null) {
        selected.session.birthplaceLabel = draft['birthplaceLabel'] as String?;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BirthForm(
            session: selected!.session,
            onboarding: true,
            initialGender:
                selected.session.gender ??
                (male ? ProfileGender.male : ProfileGender.female),
            initialDetails: draft,
          ),
        ),
      );
      await selected.session.flushStorage();
      if (!mounted || targetKey != peopleKey) return;
      if (selected.session.facts == null) {
        if (previous == null) {
          userJourney.event(
            'matching.add',
            metadata: {
              'feature': 'matching',
              'outcome': selected.session.profileRequestUnconfirmed
                  ? 'pending'
                  : 'cancelled',
            },
          );
        }
        if (previous == null &&
            !selected.session.profileRequestUnconfirmed &&
            selected.session.storageError == null) {
          await widget.removeKundli(selected, [...savedRows, selected]);
        }
        await _load();
        return;
      }
      if (selected.session.storageError != null) {
        throw StateError('Saved chart could not be stored');
      }
      if (draft != null) {
        final next = people.where((p) => !_samePerson(p, draft)).toList();
        await accountStorage.writeKey(targetKey, jsonEncode(next));
      }
      await _load();
      if (!mounted || targetKey != peopleKey) return;
      final returned =
          rows.where((r) => r.id == selected!.id).firstOrNull ?? selected;
      keepCreatedSession = identical(returned.session, selected.session);
      if (previous == null) {
        userJourney.event(
          'matching.add',
          metadata: {'feature': 'matching', 'outcome': 'success'},
        );
      }
      setState(() {
        if (male) {
          boy = returned;
          boyDraft = null;
        } else {
          girl = returned;
          girlDraft = null;
        }
        consent = false;
        error = null;
        result = null;
      });
    } catch (_) {
      if (mounted && targetKey == peopleKey) {
        if (previous == null) {
          userJourney.event(
            'matching.add',
            metadata: {
              'feature': 'matching',
              'outcome': 'failed',
              'error': 'storage',
            },
          );
        }
        await _notice(
          local(
            'Could not save the birth chart. Please retry.',
            'ஜாதகத்தைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          ),
        );
      }
    } finally {
      if (previous == null && selected != null && !keepCreatedSession) {
        selected.session.dispose();
      }
    }
  }

  Future<void> _match() async {
    if (busy || _removingPerson || !_ensureMatchingOwner()) return;
    userJourney.tap('match', feature: 'matching');
    if ((boy == null && boyDraft == null) ||
        (girl == null && girlDraft == null)) {
      await _notice(
        'Enter birth details for both people, or choose their saved birth charts.',
      );
      return;
    }
    if (boy != null && girl != null && boy!.id == girl!.id) {
      await _notice('Choose two different profiles.');
      return;
    }
    if (!consent) {
      await _notice('Confirm that both people agreed to this comparison.');
      return;
    }
    if ((boyDraft == null && boy?.session.birthInput == null) ||
        (girlDraft == null && girl?.session.birthInput == null)) {
      await _notice(
        'This saved chart has no usable birth details. Please enter the birth details again.',
      );
      return;
    }
    final boyInput = boyDraft ?? _input(boy!);
    final girlInput = girlDraft ?? _input(girl!);
    if (boyInput['datetime'] == girlInput['datetime'] &&
        boyInput['latitude'] == girlInput['latitude'] &&
        boyInput['longitude'] == girlInput['longitude'] &&
        boyInput['nickname'] == girlInput['nickname']) {
      await _notice('Choose two different profiles.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    final started = Stopwatch()..start();
    final owner = accountStorage.account;
    final reduced = MediaQuery.disableAnimationsOf(context);
    userJourney.event(
      'matching.start',
      metadata: {'feature': 'matching', 'outcome': 'started'},
    );
    try {
      final value = await widget.request('/api/kundli/matching', {
        'boy': boyInput,
        'girl': girlInput,
        'consent': true,
        'language': readingLanguage(context),
      });
      if (mounted && accountStorage.account == owner) {
        userJourney.event(
          'matching.complete',
          metadata: {
            'feature': 'matching',
            'outcome': 'success',
            'durationMs': started.elapsedMilliseconds,
          },
        );
        setState(() => result = value);
      }
      if (!reduced &&
          started.elapsedMilliseconds < matchingMotionDuration.inMilliseconds) {
        await Future<void>.delayed(
          Duration(
            milliseconds:
                matchingMotionDuration.inMilliseconds -
                started.elapsedMilliseconds,
          ),
        );
      }
      if (mounted && accountStorage.account == owner) {
        value['connectionType'] = connectionType;
        value['boyName'] = boyInput['nickname'];
        value['girlName'] = girlInput['nickname'];
        value['boyRasi'] = _rasi(true);
        value['girlRasi'] = _rasi(false);
        coinWalletRevision.value++;
        setState(() => result = value);
        await openReport(value);
      }
    } catch (e) {
      if (mounted && accountStorage.account == owner) {
        userJourney.event(
          'matching.complete',
          metadata: {
            'feature': 'matching',
            'outcome': 'failed',
            'error': 'unknown',
          },
        );
        await _notice(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MatchingSurface(
    child: PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: matchBackground,
        appBar: AppBar(
          backgroundColor: matchBackground,
          foregroundColor: matchGold,
          title: Text('Jyotara', style: matchHeading(30)),
          actions: [
            if (coinWalletEnabled && coinAccount != null)
              const HomeCoinCard(compact: true),
            IconButton(
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationCenter(),
                      ),
                    ),
              tooltip: uiText(context, 'Notifications'),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
        ),
        body: busy
            ? CinematicMatchingAnimation(
                first: '${details(true)?['nickname'] ?? ''}',
                second: '${details(false)?['nickname'] ?? ''}',
                type: connectionType,
                resultReady: result != null,
                firstRasi: SouthIndianChart.signIndex(_rasi(true)),
                secondRasi: SouthIndianChart.signIndex(_rasi(false)),
              )
            : _entry(),
      ),
    ),
  );
}

class MatchingAnimation extends StatelessWidget {
  const MatchingAnimation({
    super.key,
    required this.first,
    required this.second,
  });
  final String first, second;
  @override
  Widget build(BuildContext context) =>
      ApprovedMatchingAnimation(type: 'My Crush', first: first, second: second);
}

class MatchingResultScreen extends StatefulWidget {
  const MatchingResultScreen({super.key, required this.value});
  final Map<String, dynamic> value;
  @override
  State<MatchingResultScreen> createState() => _MatchingResultScreenState();
}

class _MatchingResultScreenState extends State<MatchingResultScreen> {
  bool saving = false, saved = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        userJourney.screen('matching_result');
      }
    });
    saved = widget.value['savedAt'] != null;
  }

  Future<void> save() async {
    if (saving || saved) return;
    setState(() => saving = true);
    try {
      await SavedMatches.save(widget.value);
      if (mounted) setState(() => saved = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readingLanguage(context) == 'ta'
                  ? 'சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.'
                  : 'Could not save. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => MatchingSurface(
    child: Scaffold(
      backgroundColor: matchBackground,
      appBar: AppBar(
        title: Text('Jyotara', style: matchHeading(30)),
        backgroundColor: matchBackground,
        foregroundColor: matchGold,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            MatchingReport(value: widget.value),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: matchBackground,
                    appBar: AppBar(title: const Text('Your connection')),
                    body: ApprovedMatchingAnimation(
                      type:
                          widget.value['connectionType']?.toString() ??
                          'Marriage',
                      first: '${widget.value['boyName'] ?? ''}',
                      second: '${widget.value['girlName'] ?? ''}',
                      replay: true,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Watch matching animation'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving || saved ? null : save,
                icon: Icon(saved ? Icons.check : Icons.bookmark_border),
                label: Text(
                  readingLanguage(context) == 'ta'
                      ? (saved
                            ? 'சேமிக்கப்பட்டது'
                            : 'பொருத்தத்தைச் சேமிக்கவும்')
                      : (saved ? 'Saved' : 'Save this match'),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                readingLanguage(context) == 'ta'
                    ? 'மற்றொரு பொருத்தம் பார்க்க'
                    : 'Match another pair',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SavedMatches {
  static String get key => accountStorage.key('jyotara.matching.results.v1');
  static Future<List<Map<String, dynamic>>> load() async {
    final raw = await KundliLibrary.storage.read(key: key);
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
  }

  static Future<void> save(Map<String, dynamic> value) async {
    final target = key;
    final rows = await load();
    if (target != key) throw StateError('Account changed');
    final copy = Map<String, dynamic>.from(value)
      ..remove('savedAt')
      ..remove('wallet')
      ..remove('replayed');
    final signature = jsonEncode(copy);
    if (rows.any(
      (r) => jsonEncode(Map.of(r)..remove('savedAt')) == signature,
    )) {
      return;
    }
    await accountStorage.writeKey(
      target,
      jsonEncode([
        {'savedAt': DateTime.now().toIso8601String(), ...copy},
        ...rows,
      ]),
    );
  }

  static Future<void> remove(Map<String, dynamic> value) async {
    final target = key;
    final rows = await load();
    if (target != key) throw StateError('Account changed');
    await accountStorage.writeKey(
      target,
      jsonEncode(
        rows.where((r) => jsonEncode(r) != jsonEncode(value)).toList(),
      ),
    );
  }
}

class SavedMatchesScreen extends StatefulWidget {
  const SavedMatchesScreen({super.key});
  @override
  State<SavedMatchesScreen> createState() => _SavedMatchesScreenState();
}

class _SavedMatchesScreenState extends State<SavedMatchesScreen> {
  late Future<List<Map<String, dynamic>>> data = SavedMatches.load();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        readingLanguage(context) == 'ta'
            ? 'சேமித்த பொருத்தங்கள்'
            : 'Saved matches',
      ),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => data = SavedMatches.load()),
              child: const UiText('Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              readingLanguage(context) == 'ta'
                  ? 'சேமித்த பொருத்தங்கள் இல்லை'
                  : 'No saved matches yet',
            ),
          );
        }
        return ListView(
          children: [
            for (final value in snapshot.data!)
              ListTile(
                title: Text('${value['boyName']} · ${value['girlName']}'),
                subtitle: Text(
                  '${value['score']} / ${value['maximum']} · ${value['savedAt']?.toString().substring(0, 10) ?? ''}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MatchingResultScreen(value: value),
                  ),
                ),
                trailing: IconButton(
                  tooltip: uiText(context, 'Delete'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    try {
                      await SavedMatches.remove(value);
                      if (mounted) setState(() => data = SavedMatches.load());
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: UiText(
                              'Could not save changes. Please retry.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class MatchingReport extends StatelessWidget {
  const MatchingReport({super.key, required this.value});
  final Map<String, dynamic> value;
  @override
  Widget build(BuildContext context) => ApprovedMatchingReport(value: value);
}
