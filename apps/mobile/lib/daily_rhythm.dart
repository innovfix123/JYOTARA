part of 'discovery_screens.dart';

const _dailyGold = BronzePalette.gold;
const _dailySurface = BronzePalette.card;
final _dailyCardGradient = BoxDecoration(
  borderRadius: BorderRadius.circular(23),
  border: Border.all(color: BronzePalette.border, width: .7),
  gradient: const RadialGradient(
    center: Alignment.topRight,
    radius: 1.5,
    colors: [_dailySurface, _dailySurface, _dailySurface],
  ),
);

String? dailyTimingOverlapExplanation(
  Map? good,
  Map? avoid, {
  required bool tamil,
  required String Function(dynamic) clock,
}) {
  if (good == null || avoid == null) return null;
  final goodStart = DateTime.tryParse('${good['start']}');
  final goodEnd = DateTime.tryParse('${good['end']}');
  final avoidStart = DateTime.tryParse('${avoid['start']}');
  final avoidEnd = DateTime.tryParse('${avoid['end']}');
  if (goodStart == null ||
      goodEnd == null ||
      avoidStart == null ||
      avoidEnd == null ||
      !goodStart.isBefore(goodEnd) ||
      !avoidStart.isBefore(avoidEnd) ||
      !goodStart.isBefore(avoidEnd) ||
      !avoidStart.isBefore(goodEnd)) {
    return null;
  }
  if (goodEnd.isAfter(avoidEnd)) {
    // Use only the existing end points; focus resumes while good time remains.
    final until = clock(avoid['end']), focusUntil = clock(good['end']);
    if (goodStart.isBefore(avoidStart)) {
      final from = clock(avoid['start']);
      return tamil
          ? 'இந்த நேரங்கள் ஒன்றுடன் ஒன்று சேர்கின்றன. $from முதல் $until வரை நிதானமாக இருங்கள்; பிறகு $focusUntil வரை கவனமாகச் செயல்படுங்கள்.'
          : 'These times overlap. Take it slow from $from until $until, then focus until $focusUntil.';
    }
    return tamil
        ? 'இந்த நேரங்கள் ஒன்றுடன் ஒன்று சேர்கின்றன. $until வரை நிதானமாக இருங்கள்; பிறகு $focusUntil வரை கவனமாகச் செயல்படுங்கள்.'
        : 'These times overlap. Take it slow until $until, then focus until $focusUntil.';
  }
  final from = clock(
    goodStart.isAfter(avoidStart) ? good['start'] : avoid['start'],
  );
  final until = clock(good['end']);
  return tamil
      ? 'இந்த நேரங்கள் ஒன்றுடன் ஒன்று சேர்கின்றன. $from–$until நேரத்தில் நிதானமாக இருங்கள்.'
      : 'These times overlap. Take it slow during $from–$until.';
}

extension _DailyRhythmLayout on _DailyHoroscopeScreenState {
  String _section(String title, {bool full = false}) {
    final rows = (readings[sign]?['sections'] as List? ?? []).whereType<Map>();
    for (final row in rows) {
      if (row['title'] == title) {
        final text =
            '${full ? row['details'] ?? row['text'] ?? '' : row['text'] ?? ''}';
        if (readingLanguage(context) == 'ta' &&
            RegExp(r'[A-Za-z]').hasMatch(text)) {
          return 'தமிழ் பலன் கிடைக்கவில்லை. மீண்டும் முயற்சிக்கவும்.';
        }
        return full ? text : dailyShortText(text);
      }
    }
    return local(
      'Reading unavailable. Please retry.',
      'பலன் கிடைக்கவில்லை. மீண்டும் முயற்சிக்கவும்.',
    );
  }

  String _oneSentence(String value) {
    final match = RegExp(r'^.*?[.!?](?:\s|$)', dotAll: true).firstMatch(value);
    return (match?.group(0) ?? value).trim();
  }

  String _clock(dynamic raw) {
    final value = DateTime.tryParse('$raw')
        ?.toUtc()
        .add(const Duration(hours: 5, minutes: 30));
    if (value == null) return '—';
    return '${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? local('AM', 'காலை') : local('PM', 'பிற்பகல்')}';
  }

  Future<void> _openTimingGuide() async {
    final guide = _prepareTimingGuide();
    var recordedGuide = false;
    userJourney.event(
      'daily.open',
      metadata: {'feature': 'daily', 'control': 'guide', 'outcome': 'started'},
    );
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DailyTimingExperience(
          title: local(
            day == 0 ? 'Today’s timings' : 'Tomorrow’s timings',
            day == 0 ? 'இன்றைய நேரங்கள்' : 'நாளைய நேரங்கள்',
          ),
          tamil: readingLanguage(context) == 'ta',
          onVideoEvent: (outcome, durationMs) => userJourney.event(
            'daily.expand',
            metadata: {
              'feature': 'daily',
              'control': 'primary',
              'outcome': outcome,
              'durationMs': durationMs,
            },
          ),
          guideBuilder: (_) {
            userJourney.screen('reading');
            return FutureBuilder<Widget?>(
              future: guide,
              builder: (_, snapshot) {
                final ready = snapshot.data;
                if (ready != null) {
                  if (!recordedGuide) {
                    recordedGuide = true;
                    userJourney.event(
                      'daily.open',
                      metadata: {
                        'feature': 'daily',
                        'control': 'guide',
                        'outcome': 'success',
                      },
                    );
                  }
                  return ready;
                }
                return Center(
                  key: const Key('dailyTimingGuideLoading'),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (snapshot.connectionState != ConnectionState.done)
                          const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          local(
                            snapshot.connectionState == ConnectionState.done
                                ? 'Guide unavailable. Please return to Daily and retry.'
                                : 'Loading your timings and reading…',
                            snapshot.connectionState == ConnectionState.done
                                ? 'வழிகாட்டல் கிடைக்கவில்லை. தினசரி பக்கத்தில் மீண்டும் முயற்சிக்கவும்.'
                                : 'உங்கள் நேரங்களும் பலனும் ஏற்றப்படுகின்றன…',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
    if (mounted) userJourney.screen('daily');
  }

  Future<Widget?> _prepareTimingGuide() async {
    await selectedTimingSourcesReady();
    if (!mounted) return null;
    return _timingGuide();
  }

  Widget _timingGuide() {
    final selectedDate = date;
    final tamil = readingLanguage(context) == 'ta';
    final rows = (calendar?['timings'] as List? ?? []).whereType<Map>();
    Map? find(String name) {
      for (final row in rows) {
        if (row['name'] == name) return row;
      }
      return null;
    }

    final good = find('Abhijit Muhurta'), avoid = find('Rahu Kalam');
    final goodWindow = DailyTimingWindow.fromProvider(good);
    final avoidWindow = DailyTimingWindow.fromProvider(avoid);
    final tips = <String>[];
    final sections = (readings[sign]?['sections'] as List? ?? [])
        .whereType<Map>();
    for (final title in ['General', 'Career', 'Love', 'Health']) {
      for (final row in sections) {
        if (row['title'] != title) continue;
        final text = '${row['text'] ?? ''}'.trim();
        if (text.isEmpty ||
            (readingLanguage(context) == 'ta' &&
                RegExp(r'[A-Za-z]').hasMatch(text))) {
          continue;
        }
        final point = _oneSentence(text);
        if (!tips.contains(point)) tips.add(point);
      }
      if (tips.length >= 3) break;
    }
    return DailyTimingGuide(
      date: selectedDate,
      tomorrow: day != 0,
      tamil: tamil,
      city:
          (city == null ? null : _dailyCityLabel(city!)) ??
          local(
            'Choose current city for timings',
            'நேரங்களுக்கு தற்போதைய ஊரைத் தேர்வுசெய்க',
          ),
      focus: goodWindow,
      caution: avoidWindow,
      focusRange: goodWindow == null
          ? local('Focus time unavailable', 'கவன நேரம் கிடைக்கவில்லை')
          : _timingRange(good!),
      cautionRange: avoidWindow == null
          ? local('Caution time unavailable', 'நிதான நேரம் கிடைக்கவில்லை')
          : _timingRange(avoid!),
      overlap: dailyTimingOverlapExplanation(
        good,
        avoid,
        tamil: readingLanguage(context) == 'ta',
        clock: _clock,
      ),
      guidance: tips.take(3).toList(),
      clock: (now) {
        final value = now.toUtc().add(DailyTimingWindow.indiaOffset);
        final period = value.hour < 12
            ? (tamil ? 'காலை' : 'AM')
            : (tamil ? 'பிற்பகல்' : 'PM');
        return '${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')} $period';
      },
      onShare: (outcome) => userJourney.event(
        'interaction.tap',
        metadata: {'feature': 'daily', 'control': 'share', 'outcome': outcome},
      ),
    );
  }

  Widget _dailyLayout() {
    const readingTopics = [
      ('General', 'Overview', 'ஒரு பார்வை'),
      ('Love', 'Relationships', 'உறவுகள்'),
      ('Career', 'Work', 'வேலை'),
      ('Health', 'Wellbeing', 'நலன்'),
    ];
    final known = profileSession.birthTimeKnown;
    final originalName = profileSession.nickname.trim();
    final name = readingLanguage(context) == 'ta'
        ? tamilDisplayName(originalName)
        : originalName;
    final rows = (calendar?['timings'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return Scaffold(
      backgroundColor: BronzePalette.background,
      appBar: MainTabScope.contains(context)
          ? null
          : AppBar(
              title: const Text('Jyotara'),
              actions: const [CompactLanguageSwitch()],
            ),
      body: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 155),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: _DailyLotusMotion(
                    tamil: readingLanguage(context) == 'ta',
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  heightFactor: 1,
                  child: SizedBox(
                    width: readingLanguage(context) == 'ta' ? 260 : 270,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PopupMenuButton<int>(
                          initialValue: day,
                          tooltip: local('Choose day', 'நாளைத் தேர்வுசெய்க'),
                          padding: EdgeInsets.zero,
                          onSelected: (d) {
                            if (day != d) {
                              updateDaily(() => day = d);
                              _load();
                              _loadCalendar();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 0, child: UiText('Today')),
                            PopupMenuItem(value: 1, child: UiText('Tomorrow')),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              MaterialLocalizations.of(context)
                                  .formatFullDate(DateTime.parse(date))
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: _dailyGold,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          local(
                            'Your day${name.isEmpty ? '' : ', $name'}.',
                            '${name.isEmpty ? 'உங்கள்' : name} நாள்.',
                          ),
                          style: const TextStyle(
                            fontFamily: 'JyotaraEditorial',
                            fontFamilyFallback: ['JyotaraTamil'],
                            fontSize: 30,
                            height: 1.1,
                            color: bodyInk,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${zodiacLabel(context, sign)} · ${local('General Rasi reading', 'பொதுவான ராசிபலன்')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('dailyPlan'),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [_dailySurface, _dailySurface, _dailySurface],
              ),
              border: Border.all(color: BronzePalette.border, width: .7),
              borderRadius: BorderRadius.circular(23),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        local(
                          day == 0 ? 'Today’s timings' : 'Tomorrow’s timings',
                          day == 0 ? 'இன்றைய நேரங்கள்' : 'நாளைய நேரங்கள்',
                        ),
                        style: const TextStyle(
                          fontFamily: 'JyotaraEditorial',
                          fontSize: 23,
                          color: bodyInk,
                        ),
                      ),
                    ),
                    Text(
                      local('IST', 'இந்திய நேரம்'),
                      style: TextStyle(fontSize: 14, color: _dailyGold),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (calendarBusy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            local(
                              'See when to focus and when to take things slowly.',
                              'எப்போது கவனம் செலுத்தலாம், எப்போது நிதானமாக இருக்கலாம் எனப் பாருங்கள்.',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: muted,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 9),
                          FilledButton.icon(
                            key: const Key('dailySeeYourDay'),
                            onPressed: _openTimingGuide,
                            icon: const Icon(
                              Icons.play_arrow_outlined,
                              size: 18,
                            ),
                            label: Text(
                              local(
                                day == 0 ? 'See your day' : 'See tomorrow',
                                day == 0
                                    ? 'இன்றைய நாளைப் பாருங்கள்'
                                    : 'நாளையைப் பாருங்கள்',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        dailyTimingImageAsset,
                        width: 64,
                        height: 84,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  key: const Key('dailyCity'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 32),
                    padding: EdgeInsets.zero,
                    foregroundColor: muted,
                  ),
                  onPressed: _chooseCity,
                  icon: const Icon(Icons.location_on_outlined, size: 13),
                  label: Text(
                    (city == null ? null : _dailyCityLabel(city!)) ??
                        local(
                          'Choose current city for timings',
                          'நேரங்களுக்கு தற்போதைய ஊரைத் தேர்வுசெய்க',
                        ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (calendarError != null)
                  TextButton(
                    onPressed: _loadCalendar,
                    child: Text(
                      '$calendarError · ${local('Retry', 'மீண்டும் முயற்சி')}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (known) ...[
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(23),
                side: const BorderSide(color: BronzePalette.border, width: .7),
              ),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: _dailyCardGradient,
                child: ExpansionTile(
                  key: const Key('dailyApproach'),
                  onExpansionChanged: (expanded) => userJourney.event(
                    'daily.expand',
                    metadata: {
                      'feature': 'daily',
                      'control': expanded ? 'primary' : 'close',
                      'outcome': 'success',
                    },
                  ),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  title: Text(
                    local('How to approach today', 'இன்றைய அணுகுமுறை'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: bodyInk,
                    ),
                  ),
                  subtitle: Text(
                    local(
                      'Physical · Emotional · Mind',
                      'உடல் · உணர்வுகள் · சிந்தனை',
                    ),
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                  leading: Image.asset(
                    'assets/images/daily-mind.png',
                    width: 25,
                    height: 25,
                    excludeFromSemantics: true,
                  ),
                  children: [
                    for (final item in [
                      (
                        'Physical',
                        'உடல்',
                        'Health',
                        'assets/images/daily-physical.png',
                      ),
                      (
                        'Emotional',
                        'உணர்வுகள்',
                        'Love',
                        'assets/images/daily-emotional.png',
                      ),
                      (
                        'Mind',
                        'சிந்தனை',
                        'Career',
                        'assets/images/daily-mind.png',
                      ),
                    ])
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: BronzePalette.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: .85, end: 1),
                              duration: Duration(
                                milliseconds:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? 0
                                    : 650,
                              ),
                              builder: (_, value, child) => Transform.scale(
                                scale: value,
                                child: Opacity(opacity: value, child: child),
                              ),
                              child: Image.asset(
                                item.$4,
                                width: 21,
                                height: 21,
                                excludeFromSemantics: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    local(item.$1, item.$2),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: bodyInk,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  if (busy)
                                    const LinearProgressIndicator(minHeight: 2)
                                  else
                                    Text(
                                      _oneSentence(_section(item.$3)),

                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: muted,
                                        height: 1.55,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      BirthForm(session: profileSession, onboarding: true),
                ),
              ),
              child: Text(
                local('Add your birth time', 'பிறந்த நேரத்தைச் சேருங்கள்'),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
          if (error != null)
            TextButton(
              onPressed: _load,
              child: Text(error!, style: const TextStyle(fontSize: 15)),
            ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(23),
            child: Ink(
              decoration: _dailyCardGradient,
              child: ExpansionTile(
                key: const Key('dailyFullReading'),
                onExpansionChanged: (expanded) => userJourney.event(
                  'daily.expand',
                  metadata: {
                    'feature': 'daily',
                    'control': expanded ? 'primary' : 'close',
                    'outcome': 'success',
                  },
                ),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                dense: false,
                title: Text(
                  local('More for today', 'இன்றைய மேலும் சில குறிப்புகள்'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: bodyInk,
                  ),
                ),
                subtitle: Text(
                  local(
                    'Overview · Relationships · Work · Wellbeing',
                    'ஒரு பார்வை · உறவுகள் · வேலை · நலன்',
                  ),
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
                leading: const Icon(
                  Icons.auto_awesome_outlined,
                  color: _dailyGold,
                  size: 25,
                ),
                children: [
                  if (busy)
                    const LinearProgressIndicator()
                  else ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < readingTopics.length; i++)
                          ChoiceChip(
                            label: Text(
                              local(readingTopics[i].$2, readingTopics[i].$3),
                              style: const TextStyle(fontSize: 14),
                            ),
                            selected: energyTab == i,
                            onSelected: (_) => updateDaily(() => energyTab = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in [readingTopics[energyTab]])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              local(item.$2, item.$3),
                              style: const TextStyle(
                                color: _dailyGold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            for (final point in dailyReadingPoints(
                              _section(item.$1, full: true),
                            ))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 13,
                                        color: _dailyGold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: bodyInk,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  for (final row in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_timingName('${row['name']}')),
                      subtitle: Text(
                        '${_clock(row['start'])} – ${_clock(row['end'])}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timingRange(Map row) {
    if (readingLanguage(context) != 'ta')
      return '${_clock(row['start'])}–${_clock(row['end'])}';
    final a = _clock(row['start']), b = _clock(row['end']);
    for (final period in ['காலை', 'பிற்பகல்']) {
      if (a.endsWith(period) && b.endsWith(period)) {
        return '${period == 'பிற்பகல்' ? 'மதியம்' : period} ${a.replaceAll(' $period', '')}–${b.replaceAll(' $period', '')}';
      }
    }
    return '$a–$b';
  }

  String _dailyCityLabel(String value) {
    if (readingLanguage(context) != 'ta') return value;
    const cities = {
      'Bengaluru': 'பெங்களூரு',
      'Bangalore': 'பெங்களூரு',
      'Chennai': 'சென்னை',
      'Erode': 'ஈரோடு',
      'Coimbatore': 'கோயம்புத்தூர்',
      'Madurai': 'மதுரை',
      'Salem': 'சேலம்',
      'Mumbai': 'மும்பை',
      'Delhi': 'டெல்லி',
      'Hyderabad': 'ஹைதராபாத்',
      'Kolkata': 'கொல்கத்தா',
    };
    final first = value.split(',').first.trim();
    return cities[first] ??
        (RegExp(r'[A-Za-z]').hasMatch(first) ? 'தேர்ந்தெடுத்த ஊர்' : first);
  }

  String _timingName(String name) => local(
    name,
    {
          'Rahu Kalam': 'ராகு காலம்',
          'Yamagandam': 'எமகண்டம்',
          'Gulikai': 'குளிகை',
          'Brahma Muhurta': 'பிரம்ம முகூர்த்தம்',
          'Abhijit Muhurta': 'அபிஜித் முகூர்த்தம்',
        }[name] ??
        name,
  );
}

/// Exact approved lotus artwork, softly masked with native water motion.
class _DailyLotusMotion extends StatefulWidget {
  const _DailyLotusMotion({required this.tamil});
  final bool tamil;
  @override
  State<_DailyLotusMotion> createState() => _DailyLotusMotionState();
}

class _DailyLotusMotionState extends State<_DailyLotusMotion>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 0;
    } else {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: motion,
      builder: (_, _) {
        final p = (1 - cos(motion.value * 2 * pi)) / 2;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, .86, 1],
          ).createShader(r),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, .12, .88, 1],
            ).createShader(r),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  right: -22,
                  top: -17,
                  width: 275,
                  height: 184,
                  child: Transform.translate(
                    offset: Offset(-2 * p, -2 * p),
                    child: Transform.scale(
                      scale: 1 + .025 * p,
                      child: Opacity(
                        opacity: widget.tamil ? .56 : .94,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0, .5, .86, 1],
                          ).createShader(r),
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (r) => const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0, .28, .78, 1],
                            ).createShader(r),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                BronzePalette.background,
                                BlendMode.screen,
                              ),
                              child: Image.asset(
                                'assets/images/daily-lotus135.webp',
                                key: const Key('dailyApprovedLotus'),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 116,
                  width: 128,
                  height: 18,
                  child: CustomPaint(
                    painter: _DailyLotusRipple(
                      (motion.value * 16 / 5) % 1,
                      MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _DailyLotusRipple extends CustomPainter {
  const _DailyLotusRipple(this.phase, this.still);
  final double phase;
  final bool still;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = still ? 1.0 : .7 + .65 * phase;
    final opacity = still ? .10 : sin(phase * pi) * .14;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * scale,
        height: size.height * scale,
      ),
      Paint()
        ..color = _dailyGold.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65,
    );
  }

  @override
  bool shouldRepaint(_DailyLotusRipple old) =>
      phase != old.phase || still != old.still;
}
