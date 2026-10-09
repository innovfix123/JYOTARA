part of 'main.dart';

bool _homeTamil(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
        ?.notifier
        ?.value ==
    'ta';
final requestedAskGroup = ValueNotifier<String>('All');
const compactEditorial = TextStyle(
  fontFamily: 'JyotaraEditorial',
  fontFamilyFallback: JyotaraFonts.fallback,
  color: bodyInk,
  fontWeight: FontWeight.w500,
);
const _homeInk = BronzePalette.ink;
const _homeMuted = BronzePalette.muted;
const _homeGold = BronzePalette.gold;
TextStyle _homeType(
  double size, {
  Color color = _homeInk,
  FontWeight weight = FontWeight.w400,
  double height = 1.35,
}) => TextStyle(
  fontFamily: 'JyotaraSans',
  fontFamilyFallback: JyotaraFonts.fallback,
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
);

/// Approved Home composition with native labels and existing feature routes.
class CompactHome extends StatelessWidget {
  const CompactHome({super.key, required this.onOpenChat});
  final ValueChanged<Guide> onOpenChat;
  void _ask(BuildContext context, [String group = 'All']) {
    requestedAskGroup.value = group;
    if (MainTabScope.contains(context)) {
      requestedMainTab.value = 3;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const UiText('Ask')),
            body: GuidesScreen(onOpenChat: onOpenChat, initialFilter: group),
          ),
        ),
      );
    }
  }

  void _daily(BuildContext context) {
    if (MainTabScope.contains(context)) {
      requestedMainTab.value = 1;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const DailyHoroscopeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    RemoteConfigScope.watch(context);
    return ColoredBox(
      color: canvasColor,
      child: ListView(
        key: const Key('homeScroll'),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
        children: [
          if (!MainTabScope.contains(context))
            Row(
              children: [
                IconButton(
                  tooltip: uiText(context, 'Account'),
                  icon: const Icon(Icons.menu),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: AccountScreen()),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Jyotara',
                    style: compactEditorial.copyWith(fontSize: 29, color: gold),
                  ),
                ),
                if (coinWalletEnabled) const HomeCoinCard(compact: true),
                IconButton(
                  tooltip: uiText(context, 'Notifications'),
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationCenter(),
                    ),
                  ),
                ),
              ],
            ),
          const _HomeWelcome(),
          if (remoteConfig.announcement.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(remoteConfig.announcement, style: _homeType(13)),
            ),
          if (remoteConfig.enabled('chat')) ...[
            _HomeAskCard(onAsk: (group) => _ask(context, group)),
            const SizedBox(height: 14),
          ],
          _HomeCardRow(
            children: [
              const _CompactRasi(),
              if (remoteConfig.enabled('matching'))
                const HomeMatchingHighlight(),
            ],
          ),
          if (remoteConfig.enabled('daily') ||
              remoteConfig.enabled('kundli')) ...[
            const SizedBox(height: 14),
            _HomeCardRow(
              children: [
                if (remoteConfig.enabled('daily'))
                  _HomeIconSquare(
                    key: const Key('homeDaily'),
                    icon: Icons.wb_sunny_outlined,
                    title: ex(context, 'Your day', 'இன்றைய நாள்'),
                    subtitle: ex(context, 'Daily guidance', 'தினசரி பலன்'),
                    onTap: () => _daily(context),
                  ),
                if (remoteConfig.enabled('kundli'))
                  _HomeIconSquare(
                    key: const Key('homeKundli'),
                    icon: Icons.diamond_outlined,
                    title: ex(context, 'Birth Chart', 'ஜாதகம்'),
                    subtitle: ex(context, 'Your Jathagam', 'பிறப்பு விவரங்கள்'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const KundliLibraryScreen(),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeWelcome extends StatelessWidget {
  const _HomeWelcome();
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: profileSession,
    builder: (context, _) {
      final rawName = profileSession.nickname.trim();
      final name = _homeTamil(context)
          ? tamilDisplayName(rawName)
          : rawName.isEmpty
          ? ''
          : '${rawName[0].toUpperCase()}${rawName.substring(1)}';
      return Padding(
        padding: const EdgeInsets.fromLTRB(3, 8, 3, 19),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty
                        ? ex(context, 'Welcome', 'வணக்கம்')
                        : ex(context, 'Hi, $name', 'வணக்கம், $name'),
                    style: _homeType(13, color: _homeMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ex(
                      context,
                      'A little clarity, every day.',
                      'உங்களுக்கான வழிகாட்டல்.',
                    ),
                    style: _homeType(20, weight: FontWeight.w600, height: 1.32),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const _HomeLanguagePicker(),
          ],
        ),
      );
    },
  );
}

class _HomeLanguagePicker extends StatelessWidget {
  const _HomeLanguagePicker();
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
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save language. Please retry.'),
              ),
            );
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _homeTamil(context) ? 'தமிழ்' : 'EN',
              style: _homeType(11, color: _homeMuted),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more, size: 15, color: _homeMuted),
          ],
        ),
      ),
    );
  }
}

class _HomeAskCard extends StatelessWidget {
  const _HomeAskCard({required this.onAsk});
  final ValueChanged<String> onAsk;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('homeGuideGroup'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: BronzePalette.border),
      gradient: RadialGradient(
        center: const Alignment(.93, -.76),
        radius: 1.25,
        colors: [
          Color.alphaBlend(
            BronzePalette.gold.withValues(alpha: .16),
            BronzePalette.card,
          ),
          BronzePalette.card,
        ],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, bounds) => Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BronzeAskOrbits()),
                ),
              ),
              Positioned(
                right: -bounds.maxWidth * .14,
                top: -4,
                bottom: 0,
                width: bounds.maxWidth * .70,
                child: const HomeSageArt(key: Key('homeSageArt')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 21, 19, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 175),
                  child: SizedBox(
                    width: (bounds.maxWidth - 38) * .69,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex(context, 'PERSONAL GUIDANCE', 'உங்களுக்காக'),
                          style:
                              _homeType(
                                11,
                                color: BronzePalette.gold,
                                weight: FontWeight.w600,
                              ).copyWith(
                                letterSpacing: _homeTamil(context) ? 0 : 1.55,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          ex(
                            context,
                            'Ask your guide',
                            'வழிகாட்டியிடம் கேளுங்கள்',
                          ),
                          style:
                              _homeType(
                                _homeTamil(context) ? 20 : 24,
                                weight: FontWeight.w600,
                                height: _homeTamil(context) ? 1.5 : 1.25,
                              ).copyWith(
                                letterSpacing: _homeTamil(context) ? 0 : -.8,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ex(
                            context,
                            'For what matters to you.',
                            'உங்கள் கேள்விகளுக்காக.',
                          ),
                          style: _homeType(13, color: _homeMuted, height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        _HomeAskButton(onTap: () => onAsk('All')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: BronzePalette.background.withValues(alpha: .3),
            border: const Border(top: BorderSide(color: BronzePalette.border)),
          ),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final topics = [
                (
                  ex(context, 'Love', 'காதல்'),
                  'Love & Marriage',
                  Icons.favorite_border,
                ),
                (
                  ex(context, 'Education', 'கல்வி'),
                  'Education & Hobbies',
                  Icons.school_outlined,
                ),
                (
                  ex(context, 'Career', 'வேலை'),
                  'Career & Business',
                  Icons.work_outline,
                ),
                (
                  ex(context, 'Family', 'குடும்பம்'),
                  'Family & Personal Life',
                  Icons.home_outlined,
                ),
              ];
              Widget tile(
                (String, String, IconData) topic,
                int index,
              ) => Container(
                decoration: index == 0
                    ? null
                    : const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: BronzePalette.border),
                        ),
                      ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onAsk(topic.$2),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(3, 12, 3, 13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(topic.$3, size: 20, color: BronzePalette.gold),
                          const SizedBox(height: 6),
                          Text(
                            topic.$1,
                            textAlign: TextAlign.center,
                            style: _homeType(11, color: BronzePalette.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (MediaQuery.textScalerOf(context).scale(11) > 16) {
                return Wrap(
                  children: [
                    for (var i = 0; i < topics.length; i++)
                      SizedBox(
                        width: bounds.maxWidth / 2,
                        child: tile(topics[i], i),
                      ),
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < topics.length; i++)
                      Expanded(child: tile(topics[i], i)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _HomeAskButton extends StatelessWidget {
  const _HomeAskButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: BronzePalette.accent,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('homeAskNow'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  ex(context, 'Ask now', 'கேளுங்கள்'),
                  style: _homeType(
                    13,
                    color: BronzePalette.onAccent,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              const Icon(
                Icons.north_east,
                size: 17,
                color: BronzePalette.onAccent,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomeCardRow extends StatelessWidget {
  const _HomeCardRow({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = scale > 1.6 || bounds.maxWidth < 260 ? 1 : 2;
      final side = (bounds.maxWidth - (columns - 1) * 12) / columns;
      // Default cards are square; enlarged text receives room to remain readable.
      final height = side * (scale > 1.2 ? scale / 1.2 : 1);
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in children)
            SizedBox(width: side, height: height, child: card),
        ],
      );
    },
  );
}

class _HomeSquare extends StatelessWidget {
  const _HomeSquare({
    super.key,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.art,
    this.free = false,
    this.glow = BronzePalette.card,
  });
  final VoidCallback onTap;
  final String title, subtitle;
  final Widget art;
  final bool free;
  final Color glow;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: BronzePalette.border),
      gradient: RadialGradient(
        center: const Alignment(.1, -.4),
        radius: 1.1,
        colors: [glow, BronzePalette.card],
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            art,
            const Positioned(top: 14, right: 13, child: _HomeCornerArrow()),
            if (free)
              Positioned(
                top: 19,
                right: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: BronzePalette.card,
                    border: Border.all(color: BronzePalette.border),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    ex(context, 'FREE', 'இலவசம்'),
                    style: _homeType(
                      10,
                      color: BronzePalette.gold,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 15,
              right: 13,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: _homeType(
                      _homeTamil(context) ? 14 : 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: _homeType(11, color: _homeMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeCornerArrow extends StatelessWidget {
  const _HomeCornerArrow();
  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(
      color: BronzePalette.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.north_east, size: 15, color: BronzePalette.gold),
  );
}

class _CompactRasi extends StatelessWidget {
  const _CompactRasi();
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: profileSession,
    builder: (context, _) {
      final facts = profileSession.facts;
      final index = SouthIndianChart.signIndex(facts?['rashi']);
      final rasi = facts == null
          ? ex(context, 'Your Rasi', 'உங்கள் ராசி')
          : _homeTamil(context)
          ? index == 11
                ? 'மீன ராசி'
                : uiText(context, '${facts['rashi']}')
          : '${facts['rashi']} Rasi';
      return _HomeSquare(
        key: const Key('compactRasi'),
        title: rasi,
        subtitle: facts == null
            ? ex(context, 'Add birth details', 'பிறப்பு விவரங்கள்')
            : ex(context, 'Your Rasi', 'உங்கள் ராசி'),
        glow: Color.alphaBlend(
          BronzePalette.gold.withValues(alpha: .11),
          BronzePalette.card,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => facts == null
                ? const BirthProfileScreen()
                : Scaffold(
                    appBar: AppBar(title: const UiText('Your chart')),
                    body: const ChartScreen(),
                  ),
          ),
        ),
        art: LayoutBuilder(
          builder: (context, bounds) => Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BronzeRasiOrbits()),
                ),
              ),
              Positioned.fill(
                child: index < 0
                    ? const Icon(
                        Icons.auto_awesome_outlined,
                        color: _homeGold,
                        size: 48,
                      )
                    : ExcludeSemantics(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                BronzePalette.card,
                                BlendMode.screen,
                              ),
                              child: HomeRasiArt(index: index),
                            ),
                          ],
                        ),
                      ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        BronzePalette.card,
                      ],
                      stops: [0, .40, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class HomeMatchingHighlight extends StatelessWidget {
  const HomeMatchingHighlight({super.key});
  @override
  Widget build(BuildContext context) => _HomeSquare(
    key: const Key('homeMatching'),
    title: ex(context, 'Matching', 'பொருத்தம்'),
    subtitle: ex(context, 'See your match', 'பொருத்தம் காண'),
    glow: BronzePalette.card,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const MatchingScreen()),
    ),
    art: LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          const Positioned.fill(
            child: LoveLetterArt(key: Key('homeLoveLetterArt'), square: true),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    BronzePalette.card,
                  ],
                  stops: [0, .40, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeIconSquare extends StatelessWidget {
  const _HomeIconSquare({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _HomeSquare(
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    free: true,
    glow: Color.alphaBlend(
      BronzePalette.gold.withValues(alpha: .12),
      BronzePalette.card,
    ),
    art: Stack(
      children: [
        Positioned(
          left: 18,
          top: 18,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: BronzePalette.gold.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 25, color: BronzePalette.gold),
          ),
        ),
      ],
    ),
  );
}

class _BronzeAskOrbits extends CustomPainter {
  const _BronzeAskOrbits();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 58, 51);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      center,
      94,
      line..color = BronzePalette.gold.withValues(alpha: .22),
    );
    canvas.drawCircle(
      center,
      112,
      line..color = BronzePalette.gold.withValues(alpha: .09),
    );
    final star = Paint()..color = BronzePalette.gold.withValues(alpha: .65);
    for (final point in [
      const Offset(.8, .08),
      const Offset(.93, .5),
      const Offset(.64, .19),
      const Offset(.87, .69),
    ]) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        point.dx < .8 ? .7 : 1,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(_BronzeAskOrbits oldDelegate) => false;
}

class _BronzeRasiOrbits extends CustomPainter {
  const _BronzeRasiOrbits();
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * .35;
    final center = Offset(size.width * .5, size.height * .07 + radius);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      center,
      radius,
      line..color = BronzePalette.gold.withValues(alpha: .19),
    );
    canvas.drawCircle(
      center,
      radius + 8,
      line..color = BronzePalette.gold.withValues(alpha: .08),
    );
  }

  @override
  bool shouldRepaint(_BronzeRasiOrbits oldDelegate) => false;
}
