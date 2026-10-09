part of 'discovery_screens.dart';

const matchGold = BronzePalette.gold;
const matchInk = BronzePalette.ink;
const matchMuted = BronzePalette.muted;
const matchBackground = BronzePalette.background;
const matchField = BronzePalette.card;
const matchContexts = ['My Crush', 'My Partner', 'My Friend', 'Marriage'];
String matchAsset(String type, int scene) =>
    'assets/images/couple/${{'My Crush': 'crush', 'My Partner': 'partner', 'My Friend': 'friend', 'Marriage': 'marriage'}[type] ?? 'crush'}-$scene.webp';
TextStyle matchHeading(double size) =>
    TextStyle(fontFamily: 'JyotaraEditorial', fontSize: size, color: matchInk);

class GoldenSticker extends StatelessWidget {
  const GoldenSticker({
    super.key,
    required this.asset,
    this.height = 235,
    this.child,
  });
  final String asset;
  final double height;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        colors: [
          Color(0x40BC8C3F),
          Color(0x2598702B),
          Color(0x10755320),
          Colors.transparent,
        ],
        stops: [0, .28, .48, .9],
        radius: .85,
      ),
    ),
    alignment: Alignment.center,
    child:
        child ??
        Image.asset(
          asset,
          width: 190,
          height: 190,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
  );
}

class ApprovedMatchingAnimation extends StatefulWidget {
  const ApprovedMatchingAnimation({
    super.key,
    required this.type,
    required this.first,
    required this.second,
    this.replay = false,
  });
  final String type, first, second;
  final bool replay;
  @override
  State<ApprovedMatchingAnimation> createState() =>
      _ApprovedMatchingAnimationState();
}

class _ApprovedMatchingAnimationState extends State<ApprovedMatchingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6600),
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      if (!MediaQuery.disableAnimationsOf(context)) motion.forward();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: AnimatedBuilder(
        animation: motion,
        builder: (_, _) {
          final reduced = MediaQuery.disableAnimationsOf(context);
          final t = reduced ? 1.0 : motion.value;
          final scene = t < .32
              ? 0
              : t < .65
              ? 1
              : 2;
          final start = [0.0, .32, .65][scene];
          final phase = ((t - start) / (scene == 2 ? .35 : .32)).clamp(
            0.0,
            1.0,
          );
          final opacity = reduced || t == 1
              ? 1.0
              : (phase / .25).clamp(0.0, 1.0);
          final scale = reduced
              ? 1.0
              : .88 + .12 * Curves.easeOut.transform((phase / .5).clamp(0, 1));
          final words = widget.type == 'My Friend'
              ? [
                  'Good company.',
                  'Your kind of friendship.',
                  'Let’s discover your connection.',
                ]
              : widget.type == 'Marriage'
              ? [
                  'A shared beginning.',
                  'A little celebration of us.',
                  'Let’s discover your connection.',
                ]
              : [
                  'A little spark.',
                  'A little closer, together.',
                  'Let’s discover your connection.',
                ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoldenSticker(
                asset: matchAsset(widget.type, scene),
                height: 280,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(
                      scene == 0 ? 22 * (1 - phase) : 0,
                      scene == 1 ? 16 * (1 - phase) : 0,
                    ),
                    child: Transform.scale(
                      scale: scale,
                      child: Image.asset(
                        matchAsset(widget.type, scene),
                        key: ValueKey('matching-sticker-$scene'),
                        width: 210,
                        height: 210,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                words[scene],
                textAlign: TextAlign.center,
                style: matchHeading(32),
              ),
              const SizedBox(height: 20),
              Text(
                t == 1 && !widget.replay
                    ? 'Comparing your two charts…'
                    : [
                        'Bringing your stories together…',
                        'Exploring your chart connection…',
                        'Your connection, in focus.',
                      ][scene],
                textAlign: TextAlign.center,
                style: const TextStyle(color: matchMuted),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 44,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= scene ? matchGold : BronzePalette.raised,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class ApprovedMatchingReport extends StatelessWidget {
  const ApprovedMatchingReport({super.key, required this.value});
  final Map<String, dynamic> value;
  @override
  Widget build(BuildContext context) {
    final score = (value['score'] as num? ?? 0).toDouble();
    final maximum = (value['maximum'] as num? ?? 0).toDouble();
    final ratio = maximum > 0 ? (score / maximum).clamp(0.0, 1.0) : 0.0;
    final factors = (value['factors'] as List? ?? []).whereType<Map>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          readingLanguage(context) == 'ta'
              ? 'உங்கள் இணைப்பு'
              : 'YOUR CONNECTION',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: matchGold,
            fontSize: 11,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '${value['boyName'] ?? 'You'} & ${value['girlName'] ?? 'Their profile'}',
          textAlign: TextAlign.center,
          style: matchHeading(28),
        ),
        const SizedBox(height: 10),
        const MatchingHeartsArt(height: 182, key: Key('matchingResultHearts')),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: matchField,
            border: Border.all(color: BronzePalette.border),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 105,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(105),
                      painter: _ApprovedGauge(ratio),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(ratio * 100).round()}%',
                            style: matchHeading(32),
                          ),
                          Text(
                            value['provisional'] == true
                                ? 'PROVISIONAL'
                                : 'CHART MATCH',
                            style: const TextStyle(
                              color: matchMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room to connect.', style: matchHeading(23)),
                    const SizedBox(height: 5),
                    Text(
                      readingLanguage(context) == 'ta'
                          ? 'வித்தியாசமான எண்ணங்கள். பொறுமையுடன் ஒருவரையொருவர் புரிந்துகொள்ளுங்கள்.'
                          : 'Different rhythms. A little patience helps you understand each other.',
                      style: const TextStyle(
                        color: matchMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${score % 1 == 0 ? score.toInt() : score} / ${maximum % 1 == 0 ? maximum.toInt() : maximum}',
                      style: const TextStyle(color: matchGold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (value['wallet'] is Map)
          Text(
            value['replayed'] == true
                ? 'Saved result · No additional coins used'
                : '${value['wallet']['coins']} coins used',
            style: const TextStyle(color: matchGold),
            textAlign: TextAlign.center,
          ),
        if (value['provisional'] == true)
          const Text(
            'Provisional comparison · Birth time unknown.',
            style: TextStyle(color: matchMuted, fontSize: 12),
          ),
        const Divider(color: BronzePalette.border),
        const SizedBox(height: 14),
        Text('A closer look at you two', style: matchHeading(27)),
        for (final f in factors)
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: matchField,
              border: Border.all(color: BronzePalette.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: matchGold,
                collapsedIconColor: matchGold,
                title: Text(
                  '${f['name'] ?? 'Your connection'}',
                  style: const TextStyle(color: matchInk),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f['score'] is num &&
                        f['maximum'] is num &&
                        (f['maximum'] as num) > 0)
                      Text(
                        '${((f['score'] as num) / (f['maximum'] as num) * 100).clamp(0, 100).round()}%',
                        style: const TextStyle(color: matchGold),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more, color: matchGold),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      '${f['description'] ?? ''}',
                      style: const TextStyle(color: matchMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Make it yours.', style: matchHeading(28)),
        for (final item in [
          (
            'studio',
            'Couple Studio',
            'Cards, outfits & stickers',
            Icons.camera_alt_outlined,
          ),
          (
            'story',
            'Our Story',
            'A memory worth keeping',
            Icons.auto_stories_outlined,
          ),
          (
            'day',
            'Our Next Day',
            'Pick something you both enjoy',
            Icons.coffee_outlined,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: BoxDecoration(
                color: matchField,
                border: Border.all(color: BronzePalette.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Image.asset(
                    'assets/images/couple/${{'studio': 'cards', 'story': 'story', 'day': 'share'}[item.$1]}-0.webp',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                  title: Text(item.$2, style: const TextStyle(color: matchInk)),
                  subtitle: Text(
                    item.$3,
                    style: const TextStyle(color: matchMuted, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: matchGold),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CoupleStudioScreen(value: value, kind: item.$1),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ApprovedGauge extends CustomPainter {
  const _ApprovedGauge(this.ratio);
  final double ratio;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, p..color = const Color(0xFF353029));
    canvas.drawArc(rect, -pi / 2, ratio * pi * 2, false, p..color = matchGold);
  }

  @override
  bool shouldRepaint(_ApprovedGauge old) => ratio != old.ratio;
}

class CoupleStudioScreen extends StatefulWidget {
  const CoupleStudioScreen({
    super.key,
    required this.value,
    required this.kind,
  });
  final Map<String, dynamic> value;
  final String kind;
  @override
  State<CoupleStudioScreen> createState() => _CoupleStudioScreenState();
}

class _CoupleStudioScreenState extends State<CoupleStudioScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        userJourney.screen('matching_studio');
      }
    });
  }

  int scene = 0;
  bool sticker = false,
      sharing = false,
      film = true,
      scoreVisible = false,
      exporting = false;
  final boundary = GlobalKey();
  late final TextEditingController caption = TextEditingController(
    text: widget.kind == 'story'
        ? 'A coffee that turned into hours of talking.'
        : 'My favourite human.',
  );
  final memory = TextEditingController(
    text: 'Getting lost, then finding our favourite café.',
  );
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  String get title => widget.kind == 'story'
      ? 'Our Story'
      : widget.kind == 'day'
      ? 'Our Next Day'
      : 'Couple Studio';
  List<String> get choices => widget.kind == 'story'
      ? ['First Hello', 'Little Adventures', 'Our Milestone']
      : widget.kind == 'day'
      ? ['Little Dance', 'Heart to Heart', 'Together Time']
      : sticker
      ? ['Heart Hug', 'Coffee Pair', 'Pinky Promise']
      : ['Picnic Pair', 'Movie Night', 'Cosy Together'];
  String get asset => sticker && widget.kind == 'studio'
      ? 'assets/images/couple/${['hug', 'coffee', 'promise'][scene]}.webp'
      : 'assets/images/couple/${widget.kind == 'story'
            ? 'story'
            : widget.kind == 'day'
            ? 'share'
            : 'cards'}-$scene.webp';
  String get names =>
      '${widget.value['boyName'] ?? 'You'} & ${widget.value['girlName'] ?? 'Their profile'}';
  @override
  void dispose() {
    caption.dispose();
    memory.dispose();
    motion.dispose();
    super.dispose();
  }

  void play() {
    motion.reset();
    if (!MediaQuery.disableAnimationsOf(context)) {
      motion.forward();
    } else {
      motion.value = 1;
    }
  }

  Widget card({bool animate = false}) => AnimatedBuilder(
    animation: motion,
    builder: (_, _) {
      final t = animate ? motion.value : 1.0;
      final shift = scene == 0
          ? Offset(sin(t * pi * 4) * 5, 0)
          : scene == 1
          ? Offset(0, -sin(t * pi) * 7)
          : Offset.zero;
      final scale = scene == 2 ? .95 + .05 * t : 1.0;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
        decoration: BoxDecoration(
          border: Border.all(color: BronzePalette.border),
          borderRadius: BorderRadius.circular(20),
          gradient: const RadialGradient(
            center: Alignment(0, -.3),
            radius: 1.1,
            colors: [
              BronzePalette.raised,
              BronzePalette.card,
              BronzePalette.background,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.kind == 'story'
                  ? 'OUR STORY'
                  : widget.kind == 'day'
                  ? 'OUR NEXT DAY'
                  : 'OUR LITTLE UNIVERSE',
              style: const TextStyle(
                color: matchMuted,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            SizedBox(
              height: 245,
              child: Transform.translate(
                offset: shift,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            Text(names, style: matchHeading(30), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              caption.text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: matchGold, fontSize: 13),
            ),
            if (widget.kind == 'story' && !sharing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  memory.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: matchMuted, fontSize: 12),
                ),
              ),
            if (scoreVisible)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${(((widget.value['score'] as num? ?? 0) / max(1, (widget.value['maximum'] as num? ?? 1))) * 100).round()}% chart match',
                  style: const TextStyle(color: matchGold),
                ),
              ),
            const SizedBox(height: 22),
            Text('Jyotara', style: matchHeading(23).copyWith(color: matchGold)),
            const SizedBox(height: 4),
            const Text(
              'Find your vibe together',
              style: TextStyle(color: matchMuted, fontSize: 10),
            ),
          ],
        ),
      );
    },
  );
  Future<Uint8List> capture() async {
    await WidgetsBinding.instance.endOfFrame;
    final node =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await node.toImage(pixelRatio: 1.25);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> share(String? target) async {
    if (exporting) return;
    userJourney.event(
      'matching.share',
      metadata: {'feature': 'matching', 'outcome': 'started'},
    );
    setState(() => exporting = true);
    motion.stop();
    try {
      final frames = <Uint8List>[];
      if (film) {
        for (var i = 0; i < 48; i++) {
          if (!mounted) return;
          motion.value = i / 47;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          frames.add(await capture());
        }
      } else {
        motion.value = 1;
        frames.add(await capture());
      }
      if (!mounted) return;
      await const MethodChannel('jyotara/couple-share').invokeMethod<void>(
        'share',
        {'frames': frames, 'animated': film, 'target': target},
      );
      // The native handoff opens a share destination; actual delivery is not
      // observable from this app and must not be reported as sent.
      userJourney.event(
        'matching.share',
        metadata: {'feature': 'matching', 'outcome': 'pending'},
      );
    } catch (_) {
      userJourney.event(
        'matching.share',
        metadata: {
          'feature': 'matching',
          'outcome': 'failed',
          'error': 'unknown',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare the share. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => exporting = false);
        play();
      }
    }
  }

  Widget input(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextField(
      controller: controller,
      maxLength: 100,
      style: const TextStyle(color: matchInk),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: matchField,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => MatchingSurface(
    child: PopScope(
      canPop: !exporting,
      child: Scaffold(
        backgroundColor: matchBackground,
        appBar: AppBar(
          title: Text(sharing ? 'Share our vibe' : title),
          backgroundColor: matchBackground,
          foregroundColor: matchGold,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: exporting
                ? null
                : () {
                    if (sharing) {
                      motion.stop();
                      setState(() => sharing = false);
                    } else {
                      Navigator.pop(context);
                    }
                  },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sharing
                    ? 'A moment to share.'
                    : widget.kind == 'story'
                    ? 'Every us has a story.'
                    : widget.kind == 'day'
                    ? 'What shall we do?'
                    : 'A little love, a little us.',
                style: matchHeading(32),
              ),
              if (sharing)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in [false, true])
                      ChoiceChip(
                        label: Text(f ? 'Animated story' : 'Photo card'),
                        selected: film == f,
                        onSelected: exporting
                            ? null
                            : (_) {
                                setState(() => film = f);
                                play();
                              },
                      ),
                  ],
                ),
              if (widget.kind == 'studio' && !sharing)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in [
                        (0, 'Under the Stars'),
                        (2, 'Coffee Date'),
                        (1, 'Movie Night'),
                      ])
                        ActionChip(
                          label: Text(entry.$2),
                          onPressed: () {
                            setState(() => scene = entry.$1);
                            play();
                          },
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                          child: InkWell(
                            onTap: exporting
                                ? null
                                : () {
                                    setState(() {
                                      scene = i;
                                      caption.text = (widget.kind == 'story'
                                          ? [
                                              'The start of our story.',
                                              'Our little adventures.',
                                              'Another memory, together.',
                                            ]
                                          : widget.kind == 'day'
                                          ? [
                                              'Save a little time for us.',
                                              'Let’s make tomorrow ours.',
                                              'Together is my favourite plan.',
                                            ]
                                          : sticker
                                          ? [
                                              'My favourite human.',
                                              'Love you a latte.',
                                              'Us? Pinky promise.',
                                            ]
                                          : [
                                              'A little picnic. A lot of us.',
                                              'My favourite movie partner.',
                                              'Home feels like you.',
                                            ])[i];
                                    });
                                    play();
                                  },
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: matchField,
                                border: Border.all(
                                  color: scene == i
                                      ? matchGold
                                      : BronzePalette.border,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                children: [
                                  Image.asset(
                                    sticker && widget.kind == 'studio'
                                        ? 'assets/images/couple/${['hug', 'coffee', 'promise'][i]}.webp'
                                        : 'assets/images/couple/${widget.kind == 'story'
                                              ? 'story'
                                              : widget.kind == 'day'
                                              ? 'share'
                                              : 'cards'}-$i.webp',
                                    height: 72,
                                    fit: BoxFit.contain,
                                  ),
                                  Text(
                                    choices[i],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: matchGold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.kind == 'story' && !sharing) ...[
                input('How did you meet?', caption),
                input('A favourite memory', memory),
                const SizedBox(height: 18),
              ],
              RepaintBoundary(
                key: boundary,
                child: card(animate: sharing && film),
              ),
              if (!sharing && widget.kind != 'story')
                input('Your caption', caption),
              if (!sharing && widget.kind == 'studio')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final f in [false, true])
                        ChoiceChip(
                          label: Text(f ? 'Love stickers' : 'Couple card'),
                          selected: sticker == f,
                          onSelected: (_) => setState(() => sticker = f),
                        ),
                    ],
                  ),
                ),
              if (!sharing && widget.kind == 'day') ...[
                const SizedBox(height: 18),
                Text(
                  ['Quiet & cosy', 'Out & about', 'Stay at home'][scene],
                  style: matchHeading(25),
                ),
                Text(
                  [
                    'A slow walk, a warm drink and time to talk.',
                    'Visit a place you have both wanted to explore.',
                    'Pick a favourite film and make dinner together.',
                  ][scene],
                  style: const TextStyle(color: matchMuted),
                ),
              ],
              if (!sharing)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() => sharing = true);
                      play();
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: Text(
                      widget.kind == 'story'
                          ? 'Make our story card'
                          : widget.kind == 'day'
                          ? 'Make an invitation'
                          : 'Preview & share',
                    ),
                  ),
                ),
              if (sharing) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: scoreVisible,
                  onChanged: exporting
                      ? null
                      : (v) => setState(() => scoreVisible = v ?? false),
                  title: const Text(
                    'Include the chart match percentage',
                    style: TextStyle(color: matchMuted, fontSize: 13),
                  ),
                ),
                if (film)
                  OutlinedButton.icon(
                    onPressed: exporting ? null : play,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play animation'),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: exporting
                            ? null
                            : () => share('com.whatsapp'),
                        child: const Text('WhatsApp'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: exporting
                            ? null
                            : () => share('com.instagram.android'),
                        child: const Text('Instagram'),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: exporting ? null : () => share(null),
                  child: const Text('More sharing options'),
                ),
                if (exporting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        LinearProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Preparing your share…',
                          style: TextStyle(color: matchGold),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Illustrated avatars · Birth details and private chats stay off your card.',
                textAlign: TextAlign.center,
                style: TextStyle(color: matchMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MatchingSurface extends StatelessWidget {
  const MatchingSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: matchBackground,
        colorScheme: base.colorScheme.copyWith(
          primary: matchGold,
          onPrimary: matchBackground,
          surface: matchBackground,
          onSurface: matchInk,
        ),
        textTheme: base.textTheme.apply(
          fontFamily: 'JyotaraSans',
          bodyColor: matchInk,
          displayColor: matchInk,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: matchGold,
            foregroundColor: matchBackground,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
