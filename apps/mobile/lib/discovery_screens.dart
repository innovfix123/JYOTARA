import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'main.dart' show testerAccess, profileSession, lavender, muted, panel;
import 'birth_form.dart';
import 'south_chart.dart';
import 'services/jyotara_api.dart';
import 'services/profile_session.dart';
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
const zodiacSymbols = [
  '♈',
  '♉',
  '♊',
  '♋',
  '♌',
  '♍',
  '♎',
  '♏',
  '♐',
  '♑',
  '♒',
  '♓',
];

Future<Map<String, dynamic>> discoveryRequest(
  String path,
  Map<String, dynamic> body,
) async {
  final response = await http
      .post(
        Uri.parse(defaultApiBaseUrl).resolve(path),
        headers: {
          'Content-Type': 'application/json',
          'X-Jyotara-Tester-Code': testerAccess.code ?? '',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 25));
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
          label: const Text('Wallet · ₹0  +'),
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
                        backgroundColor: const Color(0xFF332650),
                        child: Icon(item.$1, color: lavender, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(item.$2, textAlign: TextAlign.center),
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
    appBar: AppBar(title: const Text('Wallet')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Your balance', style: TextStyle(color: muted)),
        const Text(
          '₹0',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('Wallet preview', style: TextStyle(color: lavender)),
        const Text(
          'Choose a recharge amount to preview. Payments and deductions are not enabled during this test.',
        ),
        const SizedBox(height: 28),
        const Text(
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
                          ? const Color(0xFF332650)
                          : null,
                      side: BorderSide(
                        color: selected == amount ? lavender : muted,
                      ),
                    ),
                    child: Text('₹$amount'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Selected recharge: ₹$selected'),
        const SizedBox(height: 12),
        const FilledButton(
          onPressed: null,
          child: Text('Payments coming later'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Transaction history',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text('No transactions yet.'),
      ],
    ),
  );
}

class DailyHoroscopeScreen extends StatefulWidget {
  const DailyHoroscopeScreen({super.key});
  @override
  State<DailyHoroscopeScreen> createState() => _DailyHoroscopeScreenState();
}

class _DailyHoroscopeScreenState extends State<DailyHoroscopeScreen> {
  int sign = 0, day = 0, revision = 0;
  Map<String, dynamic>? reading;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
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
      final value = await discoveryRequest('/api/horoscope/daily', {
        'sign': zodiacIds[sign],
        'date': date,
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
    appBar: AppBar(title: const Text('Daily Horoscope')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'A little guidance for your day',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'General zodiac readings for all 12 signs. These are not personal birth-chart predictions.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
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
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: sign == i ? lavender : panel,
                      child: Text(
                        zodiacSymbols[i],
                        style: TextStyle(
                          fontSize: 28,
                          color: sign == i ? Colors.black : lavender,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      zodiacNames[i].replaceFirst(' · ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sign == i ? lavender : muted),
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
                    label: Text(['Yesterday', 'Today', 'Tomorrow'][d + 1]),
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
        Text(
          '${zodiacNames[sign]}\n$date · IST',
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
          Text(error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
        if (reading != null) ...[
          for (final section in reading!['sections'] as List)
            _ReadingCard(section['title'] as String, section['text'] as String),
          const _ReadingCard(
            'Money · everyday reminder',
            'Check your available budget before spending. Give yourself time to compare options before a purchase.',
          ),
          const _ReadingCard(
            'Health · everyday reminder',
            'Make room for rest, regular meals and comfortable movement today. A horoscope cannot assess your health.',
          ),
          const Text(
            'General, Love and Career readings: Prokerala. Money and Health are everyday reminders, not date-specific forecasts.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard(this.title, this.text);
  final String title, text;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: lavender,
            ),
          ),
          const SizedBox(height: 10),
          Text(text),
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
    api: JyotaraApiClient(testerCode: () => testerAccess.code),
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
    if (row.session.profileRequestUnconfirmed) {
      throw Exception(
        'Reopen this Kundli to recover the pending calculation before deleting it.',
      );
    }
    await row.session.clear(includeServer: row.session.canDeleteServer);
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
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Saved Kundlis could not be opened. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit([SavedKundli? row]) async {
    if (busy || (row == null && error != null)) return;
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
        title: const Text('Delete this Kundli?'),
        content: const Text(
          'This removes its saved chart from this device and the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await KundliLibrary.remove(row, rows);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Deletion was not completed. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Free Kundli')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Charts for the people you know',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Save up to 10 separate Kundlis with permission. Your own chat profile stays separate. Tester calculation limits apply.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search Kundli by name',
          ),
        ),
        const SizedBox(height: 20),
        if (busy) const LinearProgressIndicator(),
        if (error != null) ...[Text(error!), TextButton(onPressed: busy ? null : _load, child: const Text('Retry loading Kundlis'))],
        if (!busy && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Your saved Kundlis will appear here.'),
          ),
        for (final row in rows.where(
          (r) => r.session.nickname.toLowerCase().contains(query.toLowerCase()),
        ))
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                row.session.nickname.isEmpty
                    ? 'Unfinished Kundli'
                    : row.session.nickname,
              ),
              subtitle: Text(
                '${row.session.birthInput?.indiaDateTime.toString().substring(0, 10) ?? 'Add birth details'}\n${row.session.birthplaceLabel}',
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
                                  title: Text(row.session.nickname),
                                ),
                                body: ListView(
                                  padding: const EdgeInsets.all(20),
                                  children: [
                                    SouthIndianChart(facts: row.session.facts!),
                                    const SizedBox(height: 16),
                                    Text(
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
                    tooltip: 'Edit Kundli',
                    onPressed: busy ? null : () => _edit(row),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete Kundli',
                    onPressed: busy ? null : () => _remove(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy || error != null ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Create New Kundli'),
        ),
      ],
    ),
  );
}

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});
  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  List<SavedKundli> rows = [];
  SavedKundli? boy, girl;
  bool consent = false, busy = false;
  String? error;
  Map<String, dynamic>? result;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await KundliLibrary.load();
      if (mounted) {
        setState(() {
          rows = [
            if (profileSession.facts != null)
              SavedKundli('personal', profileSession),
            ...saved.where((r) => r.session.facts != null),
          ];
          boy = null;
          girl = null;
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
      'datetime': b.dateTime,
      'latitude': b.latitude,
      'longitude': b.longitude,
      'exactTime': b.exactTime,
    };
  }

  Future<void> _match() async {
    if (boy == null || girl == null || boy!.id == girl!.id || !consent) {
      setState(
        () => error = 'Select two different profiles and confirm permission.',
      );
      return;
    }
    if (!boy!.session.birthTimeKnown || !girl!.session.birthTimeKnown) {
      setState(
        () => error = 'This matching calculation needs confirmed birth times for both people. Update the Kundlis first.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final value = await discoveryRequest('/api/kundli/matching', {
        'boy': _input(boy!),
        'girl': _input(girl!),
        'consent': true,
      });
      if (mounted) setState(() => result = value);
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
    appBar: AppBar(title: const Text('Kundli Matching')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Compare two birth charts',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Traditional Ashta Kuta matching · 36 points. This calculation uses the male and female roles of that system; it does not measure love or guarantee a marriage outcome.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        for (final male in [true, false])
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: DropdownButtonFormField<String>(
                key: ValueKey('${male ? "boy" : "girl"}:${male ? boy?.id : girl?.id}'),
              initialValue: male ? boy?.id : girl?.id,
              decoration: InputDecoration(
                labelText: male ? "Boy’s Kundli" : "Girl’s Kundli",
              ),
              isExpanded: true,
              items: [
                for (final row in rows.where(
                  (r) => r.session.gender?.value == (male ? 'male' : 'female'),
                ))
                  DropdownMenuItem(
                    value: row.id,
                    child: Text(
                      row.session.nickname.isEmpty
                          ? 'Saved profile'
                          : row.session.nickname,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (id) => setState(() {
                      if (male) {
                        boy = rows.firstWhere((r) => r.id == id);
                      } else {
                        girl = rows.firstWhere((r) => r.id == id);
                      }
                      result = null;
                    }),
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
          label: const Text('Create or edit Kundlis'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: busy ? null : (v) => setState(() => consent = v ?? false),
          title: const Text(
            'Both people have agreed to use their birth details for this comparison.',
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!),
          ),
        FilledButton(
          onPressed: busy ? null : _match,
          child: Text(busy ? 'Comparing…' : 'Match Horoscope'),
        ),
        if (result != null) ...[
          const SizedBox(height: 24),
          _ReadingCard(
            '${result!['score']} / ${result!['maximum']} points',
            result!['interpretation'] as String,
          ),
          Text(result!['note'] as String),
          const SizedBox(height: 12),
          Text(
            result!['source'] as String,
            style: const TextStyle(color: muted),
          ),
        ],
      ],
    ),
  );
}
