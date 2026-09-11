import 'brand_mark.dart';
import 'services/ui_language.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'main.dart'
    show
        phoneAccess,
        testerAccess,
        profileSession,
        languagePreferences,
        ivory,
        muted;
import 'birth_form.dart';
import 'south_chart.dart';
import 'services/jyotara_api.dart';
import 'services/profile_session.dart';
import 'services/profile_gender.dart';
import 'services/local_profile_vault.dart';

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
            'ta' ||
        languagePreferences.value == 'tamil'
    ? 'ta'
    : 'en';

String readingText(BuildContext context, String value) =>
    readingLanguage(context) == 'ta' ? tamilUi[value] ?? value : value;

String zodiacLabel(BuildContext context, int index) =>
    uiText(context, zodiacNames[index]);

Future<Map<String, dynamic>> discoveryRequest(
  String path,
  Map<String, dynamic> body,
) async {
  final response = await http
      .post(
        Uri.parse(defaultApiBaseUrl).resolve(path),
        headers: {
          'Content-Type': 'application/json',
          if (const bool.fromEnvironment('JYOTARA_REQUIRE_PHONE_AUTH'))
            'X-Jyotara-Phone-Auth': 'required',
          'X-Jyotara-Tester-Code': testerAccess.code ?? '',
          if (phoneAccess.token != null)
            'Authorization': 'Bearer ${phoneAccess.token}',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 90));
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw Exception(data['error'] ?? 'Please try again later.');
  }
  return data;
}

class DiscoveryActions extends StatelessWidget {
  const DiscoveryActions({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
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
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in [
            (
              Icons.wb_sunny_outlined,
              'Daily\nHoroscope',
              const DailyHoroscopeScreen(),
            ),
            (
              Icons.grid_on_rounded,
              'Free\nKundli',
              const KundliLibraryScreen(),
            ),
            (Icons.favorite_border, 'Kundli\nMatching', const MatchingScreen()),
          ])
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => item.$3),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF66402C),
                        child: Icon(item.$1, color: ivory, size: 28),
                      ),
                      const SizedBox(height: 10),
                      UiText(item.$2, textAlign: TextAlign.center),
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
        const UiText('Wallet preview', style: TextStyle(color: ivory)),
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
                          ? const Color(0xFF66402C)
                          : null,
                      side: BorderSide(
                        color: selected == amount ? ivory : muted,
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
  const DailyHoroscopeScreen({super.key, this.request = discoveryRequest});
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  request;
  @override
  State<DailyHoroscopeScreen> createState() => _DailyHoroscopeScreenState();
}

class _DailyHoroscopeScreenState extends State<DailyHoroscopeScreen> {
  int sign = 0, day = 0, revision = 0;
  Map<String, dynamic>? reading;
  String? error;
  bool busy = false;
  String? _language;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final value = readingLanguage(context);
    if (_language != value) {
      _language = value;
      _load();
    }
  }

  String get date => DateTime.now()
      .toUtc()
      .add(Duration(hours: 5, minutes: 30, days: day))
      .toIso8601String()
      .substring(0, 10);
  Future<void> _load() async {
    final current = ++revision;
    setState(() {
      busy = true;
      reading = null;
      error = null;
    });
    try {
      final value = await widget.request('/api/horoscope/daily', {
        'sign': zodiacIds[sign],
        'date': date,
        'language': readingLanguage(context),
      });
      if (mounted && current == revision) setState(() => reading = value);
    } catch (e) {
      if (mounted && current == revision) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && current == revision) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('Daily Horoscope')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const UiText(
          'A little guidance for your day',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const UiText(
          'General zodiac readings for all 12 signs. These are not personal birth-chart predictions.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 144,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 110,
              child: InkWell(
                onTap: () {
                  setState(() => sign = i);
                  _load();
                },
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sign == i ? ivory : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: RasiFigure(index: i),
                    ),
                    const SizedBox(height: 8),
                    UiText(
                      zodiacLabel(context, i).replaceFirst(' · ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sign == i ? ivory : muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            for (final d in [-1, 0, 1])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ChoiceChip(
                    label: UiText(['Yesterday', 'Today', 'Tomorrow'][d + 1]),
                    selected: day == d,
                    onSelected: (_) {
                      setState(() => day = d);
                      _load();
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Center(child: RasiFigure(index: sign, size: 96)),
        const SizedBox(height: 12),
        UiText(
          '${zodiacLabel(context, sign)}\n$date · IST',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        if (error != null) ...[
          UiText(error!),
          TextButton(onPressed: _load, child: const UiText('Retry')),
        ],
        if (reading != null) ...[
          for (final section in reading!['sections'] as List)
            _ReadingCard(
              section['title'] as String,
              section['text'] as String,
              details: section['details'] as String?,
            ),
          const _ReadingCard(
            'Money · everyday reminder',
            'Check your available budget before spending. Give yourself time to compare options before a purchase.',
          ),
          const _ReadingCard(
            'Health · everyday reminder',
            'Make room for rest, regular meals and comfortable movement today. A horoscope cannot assess your health.',
          ),
          const UiText(
            'General, Love and Career are daily readings. Money and Health are everyday reminders, not date-specific forecasts.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard(this.title, this.text, {this.details});
  final String? details;
  final String title, text;
  @override
  Widget build(BuildContext context) => Card(
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
              color: ivory,
            ),
          ),
          const SizedBox(height: 10),
          UiText(readingText(context, text)),
          if (details != null && details != text)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: UiText(readingText(context, 'Full reading')),
              children: [UiText(details!)],
            ),
        ],
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
  static const indexKey = 'jyotara.kundli.index.v1';
  static Future<List<SavedKundli>> load() async {
    final raw = await storage.read(key: indexKey);
    final ids = raw == null
        ? <String>[]
        : (jsonDecode(raw) as List).cast<String>();
    final result = <SavedKundli>[];
    for (final id in ids) {
      if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
        throw const FormatException('Invalid saved Kundli');
      }
      final session = _session(id);
      await session.restore();
      result.add(SavedKundli(id, session));
    }
    return result;
  }

  static ProfileSession _session(String id) => ProfileSession(
    api: JyotaraApiClient(
      testerCode: () => testerAccess.code,
      phoneToken: () => phoneAccess.token,
    ),
    vault: LocalProfileVault(
      read: () => storage.read(key: 'jyotara.kundli.$id'),
      write: (value) => value == null
          ? storage.delete(key: 'jyotara.kundli.$id')
          : storage.write(key: 'jyotara.kundli.$id', value: value),
    ),
  );
  static Future<SavedKundli> create(List<SavedKundli> rows) async {
    if (rows.length >= 10) {
      throw Exception(
        'You can save up to 10 Kundlis. Remove one to add another.',
      );
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await storage.write(
      key: indexKey,
      value: jsonEncode([...rows.map((r) => r.id), id]),
    );
    return SavedKundli(id, _session(id));
  }

  static Future<void> remove(SavedKundli row, List<SavedKundli> rows) async {
    if (row.session.storageError != null) {
      throw Exception(row.session.storageError);
    }
    if (row.session.facts == null) {
      await row.session.discardUnfinished();
    } else {
      await row.session.clear(includeServer: row.session.canDeleteServer);
    }
    if (row.session.storageError != null) {
      throw Exception(row.session.storageError);
    }
    await storage.write(
      key: indexKey,
      value: jsonEncode(
        rows.where((r) => r.id != row.id).map((r) => r.id).toList(),
      ),
    );
  }
}

class KundliLibraryScreen extends StatefulWidget {
  const KundliLibraryScreen({super.key});
  @override
  State<KundliLibraryScreen> createState() => _KundliLibraryScreenState();
}

class _KundliLibraryScreenState extends State<KundliLibraryScreen> {
  List<SavedKundli> rows = [];
  String query = '';
  String? error;
  bool busy = true;
  bool libraryLoaded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await KundliLibrary.load();
      if (mounted) {
        setState(() {
          rows = value;
          libraryLoaded = true;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          libraryLoaded = false;
          error = 'Saved Kundlis could not be opened. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
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
          builder: (_) => BirthForm(session: selected.session),
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
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UiText('Delete this Kundli?'),
        content: const UiText(
          'This removes its saved chart from this device and the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const UiText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const UiText('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await KundliLibrary.remove(row, rows);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('Free Kundli')),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        const UiText(
          'Charts for the people you know',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const UiText(
          'Save up to 10 separate Kundlis with permission. Your own chat profile stays separate. Up to 10 new chart sessions per tester per day.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: uiText(context, 'Search Kundli by name'),
          ),
        ),
        const SizedBox(height: 20),
        if (busy) const LinearProgressIndicator(),
        if (error != null) ...[
          UiText(error!),
          TextButton(
            onPressed: busy ? null : _load,
            child: const UiText('Retry loading Kundlis'),
          ),
        ],
        if (!busy && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: UiText('Your saved Kundlis will appear here.'),
          ),
        for (final row in rows.where(
          (r) => r.session.nickname.toLowerCase().contains(query.toLowerCase()),
        ))
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: UiText(
                row.session.nickname.isEmpty
                    ? 'Unfinished Kundli'
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
                                    SouthIndianChart(facts: row.session.facts!),
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: uiText(context, 'Edit Kundli'),
                    onPressed: busy ? null : () => _edit(row),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: uiText(context, 'Delete Kundli'),
                    onPressed: busy ? null : () => _remove(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy || !libraryLoaded ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const UiText('Create New Kundli'),
        ),
      ],
    ),
  );
}

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key, this.request = discoveryRequest, this.loadKundlis = KundliLibrary.load});
  final Future<List<SavedKundli>> Function() loadKundlis;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  request;
  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  List<SavedKundli> rows = [];
  SavedKundli? boy, girl;
  Map<String, dynamic>? boyDraft, girlDraft;
  bool consent = false, busy = false, openSaved = false;
  String searchName = '';
  bool selectBoy = true;
  String? error;
  Map<String, dynamic>? result;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.loadKundlis();
      if (mounted) {
        setState(() {
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
      if (mounted) setState(() => error = 'Could not open saved Kundlis.');
    }
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

  String _detailsLabel(bool male) {
    final selected = male ? boy : girl;
    final data =
        (male ? boyDraft : girlDraft) ??
        (selected?.session.birthInput == null ? null : _input(selected!));
    if (data == null) return uiText(context, 'No birth details entered yet.');
    final stamp = DateTime.parse(data['datetime'] as String)
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
    return '${data['nickname'] ?? uiText(context, 'Saved profile')}\n${stamp.substring(0, 10)} · ${data['exactTime'] == true ? '${stamp.substring(11, 16)} IST · ${uiText(context, 'confirmed birth time')}' : uiText(context, 'Birth time unknown — provisional comparison')}\n${data['birthplaceLabel'] ?? ''}';
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

  Future<void> _enterBirth(bool male) async {
    final session = ProfileSession(
      api: JyotaraApiClient(
        testerCode: () => testerAccess.code,
        phoneToken: () => phoneAccess.token,
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BirthForm(
          session: session,
          initialGender: male ? ProfileGender.male : ProfileGender.female,
          initialDetails:
              (male ? boyDraft : girlDraft) ??
              ((male ? boy : girl)?.session.birthInput == null
                  ? null
                  : _input((male ? boy : girl)!)),
          onSubmit: (data) async {
            if (!mounted) return;
            setState(() {
              if (male) {
                boyDraft = data;
                boy = null;
              } else {
                girlDraft = data;
                girl = null;
              }
              error = null;
              result = null;
            });
          },
        ),
      ),
    );
    session.dispose();
  }

  Future<void> _match() async {
    if (busy) return;
    if ((boy == null && boyDraft == null) ||
        (girl == null && girlDraft == null)) {
      await _notice(
        'Enter birth details for both people, or choose their saved Kundlis.',
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

    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final value = await widget.request('/api/kundli/matching', {
        'boy': boyInput,
        'girl': girlInput,
        'consent': true,
        'language': readingLanguage(context),
      });
      if (mounted) {
        value['boyName'] = boyInput['nickname'];
        value['girlName'] = girlInput['nickname'];
        setState(() => result = value);
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MatchingReport(value: value),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const UiText('Done'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await _notice(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('Kundli Matching')),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        const UiText(
          'Compare two birth charts',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const UiText(
          'Traditional Ashta Kuta matching · 36 points. This calculation uses the male and female roles of that system; it does not measure love or guarantee a marriage outcome.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        const UiText(
          'If a birth time is unknown, we use noon for a provisional comparison. The score may change with the actual time.',
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: UiText('Open Kundli'), icon: Icon(Icons.folder_open)),
            ButtonSegment(value: false, label: UiText('New Matching'), icon: Icon(Icons.add)),
          ],
          selected: {openSaved},
          onSelectionChanged: busy ? null : (v) => setState(() => openSaved = v.first),
        ),
        const SizedBox(height: 16),
        if (openSaved) ...[
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: UiText('Boy’s Kundli')), ButtonSegment(value: false, label: UiText('Girl’s Kundli'))],
            selected: {selectBoy},
            onSelectionChanged: busy ? null : (v) => setState(() => selectBoy = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => searchName = v.trim().toLowerCase()),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: uiText(context, 'Search Kundli by name')),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const UiText('No saved Kundlis yet. Use New Matching to enter birth details.'),
          if (rows.isNotEmpty && !rows.any((r) => r.session.nickname.toLowerCase().contains(searchName))) const UiText('No matching names found.'),
          for (final row in rows.where((r) => r.session.nickname.toLowerCase().contains(searchName)))
            Card(child: ListTile(
              key: ValueKey('matching-saved-${row.id}'),
              leading: CircleAvatar(child: Text(row.session.nickname.isEmpty ? '?' : row.session.nickname.substring(0, 1).toUpperCase())),
              title: Text(row.session.nickname.isEmpty ? uiText(context, 'Saved profile') : row.session.nickname),
              subtitle: Text('${row.session.birthInput!.indiaDateTime.toIso8601String().substring(0, 10)} · ${row.session.birthInput!.exactTime ? row.session.birthInput!.indiaDateTime.toIso8601String().substring(11, 16) : uiText(context, 'Unknown birth time')}\n${row.session.birthplaceLabel ?? ''}'),
              isThreeLine: true,
              selected: (selectBoy ? boy : girl)?.id == row.id,
              trailing: (selectBoy ? boy : girl)?.id == row.id ? const Icon(Icons.check_circle) : const Icon(Icons.circle_outlined),
              onTap: busy || (selectBoy ? girl : boy)?.id == row.id ? null : () => setState(() {
                if (selectBoy) { boy = row; boyDraft = null; } else { girl = row; girlDraft = null; }
                consent = false; error = null; result = null;
              }),
            )),
          const SizedBox(height: 12),
        ],
        for (final male in [true, false])
          _ReadingCard(
            male
                ? 'Boy: details used for matching'
                : 'Girl: details used for matching',
            _detailsLabel(male),
          ),
        if (!openSaved) for (final male in [true, false])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _enterBirth(male),
              icon: const Icon(Icons.person_add_alt),
              label: UiText(
                '${uiText(context, male ? "Boy" : "Girl")}: ${(male ? boyDraft : girlDraft)?['nickname'] ?? uiText(context, "Enter birth details")}',
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const KundliLibraryScreen(),
                    ),
                  );
                  await _load();
                },
          icon: const Icon(Icons.add),
          label: const UiText('Create or edit Kundlis'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: busy ? null : (v) => setState(() => consent = v ?? false),
          title: UiText(
            consent
                ? 'Permission confirmed for both people.'
                : 'I confirm both people agree to this comparison.',
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: UiText(error!),
          ),
        FilledButton(
          onPressed: busy ? null : _match,
          child: UiText(busy ? 'Comparing…' : 'Match Horoscope'),
        ),
        if (result != null) ...[
          const SizedBox(height: 24),
          MatchingReport(value: result!),
        ],
      ],
    ),
  );
}

class MatchingReport extends StatelessWidget {
  const MatchingReport({super.key, required this.value});
  final Map<String, dynamic> value;
  String number(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  @override
  Widget build(BuildContext context) {
    final score = (value['score'] as num).toDouble();
    final maximum = (value['maximum'] as num).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (value['boyName'] != null || value['girlName'] != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('${value['boyName'] ?? ''} · ${value['girlName'] ?? ''}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
      Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        UiText(value['provisional'] == true ? 'Provisional comparison' : 'Compatibility score', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        SizedBox(height: 155, child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (score / maximum).clamp(0, 1)),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 800),
          builder: (_, progress, _) => CustomPaint(size: const Size(280, 155), painter: _MatchingGauge(progress)),
        )),
        Text('${number(score)} / ${number(maximum)}', style: Theme.of(context).textTheme.headlineLarge),
      ]))),
      const SizedBox(height: 16),
      UiText(value['interpretation'] as String),
      const SizedBox(height: 12),
      UiText(value['note'] as String),
      const SizedBox(height: 20),
      if (value['factors'] is List) ...[
        const UiText('Score breakdown', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        for (final f in (value['factors'] as List).whereType<Map>())
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(f['name'] as String, style: Theme.of(context).textTheme.titleMedium)), Text('${number(f['score'] as num)} / ${number(f['maximum'] as num)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: ((f['score'] as num) / (f['maximum'] as num)).clamp(0, 1)),
            const SizedBox(height: 12),
            Text(f['description'] as String),
          ]))),
      ],
      for (final role in ['boy', 'girl'])
        if (value['${role}Mangal'] is Map)
          _ReadingCard('${value['${role}Name'] ?? uiText(context, role == 'boy' ? 'Boy' : 'Girl')} · ${uiText(context, 'Mangal Dosha')}',
            '${uiText(context, value['${role}Mangal']['present'] == true ? 'Present' : 'Not present')}${value['${role}Mangal']['exception'] == true ? ' · ${uiText(context, 'Exception reported')}' : ''}'),
    ]);
  }
}

class _MatchingGauge extends CustomPainter {
  _MatchingGauge(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 12);
    final radius = min(size.width / 2 - 20, size.height - 25);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const colors = [Color(0xffc95649), Color(0xffdc883a), Color(0xffdfb442), Color(0xff80a660), Color(0xff398567)];
    for (var i = 0; i < colors.length; i++) {
      canvas.drawArc(rect, pi + i * pi / 5, pi / 5 - 0.018, false, Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = 24);
    }
    final angle = pi + pi * progress;
    canvas.drawLine(center, center + Offset(cos(angle), sin(angle)) * (radius - 12), Paint()..color = const Color(0xff68392b)..strokeWidth = 5..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xff68392b));
  }
  @override
  bool shouldRepaint(_MatchingGauge oldDelegate) => oldDelegate.progress != progress;
}
