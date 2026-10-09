import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'bronze_theme.dart';
import 'daily_timing_data.dart';

const dailyTimingVideoAsset = 'assets/videos/daily-celestial142.mp4';
const dailyTimingImageAsset = 'assets/images/daily-celestial142.jpg';
const dailyTimingVideoDuration = Duration(seconds: 8);

/// The small playback interface lets navigation be verified without a native
/// video platform. Production always plays the bundled supplied animation.
abstract class DailyTimingPlayback implements Listenable {
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Duration get position;
  bool get completed;
  bool get failed;
  Widget view();
}

class _AssetTimingPlayback implements DailyTimingPlayback {
  final controller = VideoPlayerController.asset(dailyTimingVideoAsset);

  @override
  Future<void> initialize() async {
    await controller.initialize();
    await controller.setLooping(false);
    await controller.setVolume(0);
  }

  @override
  Future<void> play() => controller.play();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> dispose() => controller.dispose();
  @override
  Duration get position => controller.value.position;
  @override
  bool get completed => controller.value.isCompleted;
  @override
  bool get failed => controller.value.hasError;
  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);
  @override
  Widget view() {
    final size = controller.value.size;
    // The supplied 1080x1920 rendition contains 150px encoded bars at
    // either end. Clip those bars before fitting the artwork to the screen.
    final artworkHeight = size.height * (1620 / 1920);
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: artworkHeight,
            child: ClipRect(
              child: OverflowBox(
                minHeight: size.height,
                maxHeight: size.height,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyTimingExperience extends StatefulWidget {
  const DailyTimingExperience({
    super.key,
    required this.title,
    required this.guideBuilder,
    required this.tamil,
    this.playbackFactory,
    this.onVideoEvent,
  });

  final String title;
  final bool tamil;
  final WidgetBuilder guideBuilder;
  final DailyTimingPlayback Function()? playbackFactory;
  final void Function(String outcome, int durationMs)? onVideoEvent;

  @override
  State<DailyTimingExperience> createState() => _DailyTimingExperienceState();
}

class _DailyTimingExperienceState extends State<DailyTimingExperience>
    with WidgetsBindingObserver {
  DailyTimingPlayback? _playback;
  Timer? _deadline;
  int _activeMilliseconds = 0;
  bool _attempted = false, _ready = false, _guide = false;
  bool _foreground = true, _resume = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_attempted) return;
    _attempted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _guide = true;
      widget.onVideoEvent?.call('cancelled', 0);
    } else {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final playback = _playback =
        widget.playbackFactory?.call() ?? _AssetTimingPlayback();
    widget.onVideoEvent?.call('started', 0);
    try {
      await playback.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || _guide) return;
      playback.addListener(_changed);
      setState(() => _ready = true);
      if (_foreground) {
        _startDeadline();
        await playback.play();
      } else {
        _resume = true;
      }
    } catch (_) {
      if (mounted && !_guide) _openGuide('unavailable');
    }
  }

  void _startDeadline() {
    _deadline?.cancel();
    var lastTick = 0;
    _deadline = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _activeMilliseconds += (timer.tick - lastTick) * 500;
      lastTick = timer.tick;
      if (mounted && !_guide && _activeMilliseconds >= 12000) {
        _openGuide('unavailable');
      }
    });
  }

  void _changed() {
    final playback = _playback;
    if (!mounted || _guide || playback == null) return;
    if (playback.failed) {
      _openGuide('unavailable');
    } else if (playback.completed ||
        playback.position >= dailyTimingVideoDuration) {
      _openGuide('success');
    } else {
      setState(() {});
    }
  }

  void _openGuide(String outcome) {
    if (_guide) return;
    final elapsed = _playback?.position.inMilliseconds ?? 0;
    _releasePlayback();
    widget.onVideoEvent?.call(outcome, elapsed);
    setState(() {
      _guide = true;
      if (outcome == 'unavailable') {
        _notice = widget.tamil
            ? 'வீடியோ கிடைக்கவில்லை. உங்கள் நேர வழிகாட்டல் கீழே உள்ளது.'
            : 'Video unavailable. Your timing guide is below.';
      }
    });
  }

  void _releasePlayback() {
    _deadline?.cancel();
    final playback = _playback;
    _playback = null;
    playback?.removeListener(_changed);
    unawaited(playback?.dispose().catchError((_) {}) ?? Future<void>.value());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_guide || !_ready) return;
    if (_foreground) {
      if (_resume) {
        _resume = false;
        _startDeadline();
        unawaited(
          _playback!.play().catchError((_) {
            if (mounted && !_guide) _openGuide('unavailable');
          }),
        );
      }
    } else {
      _resume = true;
      _deadline?.cancel();
      unawaited(_playback!.pause().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releasePlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BronzePalette.background,
    appBar: _guide ? AppBar(title: Text(widget.title)) : null,
    body: _guide
        ? Column(
            children: [
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
              Expanded(child: widget.guideBuilder(context)),
            ],
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: widget.tamil
                    ? 'எட்டு வினாடி வானியல் அனிமேஷன்'
                    : 'Eight second celestial animation',
                child: _ready
                    ? _playback!.view()
                    : const Center(child: CircularProgressIndicator()),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        BronzePalette.background,
                        BronzePalette.background.withValues(alpha: 0),
                        BronzePalette.background.withValues(alpha: 0),
                        BronzePalette.background,
                      ],
                      stops: const [0, .20, .68, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    ListTile(leading: BackButton(), title: Text(widget.title)),
                    const Spacer(),
                    if (_ready)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: LinearProgressIndicator(
                          value: (_playback!.position.inMilliseconds / 8000)
                              .clamp(0.0, 1.0),
                          semanticsLabel: widget.tamil
                              ? 'வீடியோ முன்னேற்றம்'
                              : 'Video progress',
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton.icon(
                        key: const Key('dailyTimingSkip'),
                        onPressed: () => _openGuide('cancelled'),
                        icon: const Icon(Icons.skip_next_outlined),
                        label: Text(
                          widget.tamil
                              ? 'நேர வழிகாட்டலுக்குச் செல்லுங்கள்'
                              : 'Skip to your timing guide',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}

class DailyTimingGuide extends StatefulWidget {
  const DailyTimingGuide({
    super.key,
    required this.date,
    required this.tamil,
    required this.city,
    required this.focus,
    required this.caution,
    required this.focusRange,
    required this.cautionRange,
    required this.overlap,
    required this.guidance,
    required this.clock,
    this.tomorrow = false,
    this.now,
    this.onShare,
  });

  final String date, city, focusRange, cautionRange;
  final bool tamil, tomorrow;
  final DailyTimingWindow? focus, caution;
  final String? overlap;
  final List<String> guidance;
  final String Function(DateTime) clock;
  final DateTime Function()? now;
  final void Function(String outcome)? onShare;

  @override
  State<DailyTimingGuide> createState() => _DailyTimingGuideState();
}

class _DailyTimingGuideState extends State<DailyTimingGuide> {
  final _boundary = GlobalKey();
  Timer? _timer;
  bool _sharing = false;
  String local(String en, String ta) => widget.tamil ? ta : en;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    widget.onShare?.call('started');
    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (!mounted || bytes == null) return;
        await const MethodChannel('jyotara/couple-share')
            .invokeMethod<void>('share', {
              'frames': [bytes.buffer.asUint8List()],
              'animated': false,
            });
        widget.onShare?.call('pending');
      } finally {
        image.dispose();
      }
    } catch (_) {
      widget.onShare?.call('failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              local(
                'Could not prepare the share. Please try again.',
                'பகிர்வைத் தயாரிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now?.call() ?? DateTime.now();
    final nowFraction = DailyTimingWindow.nowFraction(widget.date, now);
    return SingleChildScrollView(
      key: const Key('dailyTimingGuide'),
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: _boundary,
            child: ColoredBox(
              color: BronzePalette.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      dailyTimingImageAsset,
                      height: 145,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.22),
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BronzePalette.card,
                      border: Border.all(color: BronzePalette.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          local(
                            'Your day, by the hour',
                            'இன்றைய நேர வழிகாட்டல்',
                          ),
                          style: const TextStyle(
                            color: BronzePalette.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(widget.date))} · ${local('IST', 'இந்திய நேரம்')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: BronzePalette.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          label: [
                            local(
                              '24 hour timing guide.',
                              '24 மணி நேர வழிகாட்டல்.',
                            ),
                            '${local('Focus time', 'கவனமாகச் செயல்பட')}: ${widget.focusRange}.',
                            '${local('Take it slow', 'நிதானமாக இருங்கள்')}: ${widget.cautionRange}.',
                            if (nowFraction != null)
                              '${local('Now', 'இப்போது')}: ${widget.clock(now)}.',
                          ].join(' '),
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                SizedBox(
                                  key: const Key('dailyTimingAxis'),
                                  height: 22,
                                  child: LayoutBuilder(
                                    builder: (_, constraints) {
                                      final labelWidth =
                                          constraints.maxWidth / 4;
                                      return Stack(
                                        children: [
                                          for (final item in [
                                            local('12 AM', 'இரவு 12'),
                                            local('6 AM', 'காலை 6'),
                                            local('12 PM', 'பகல் 12'),
                                            local('6 PM', 'மாலை 6'),
                                            local('12 AM', 'இரவு 12'),
                                          ].asMap().entries)
                                            Positioned(
                                              left: item.key == 0
                                                  ? 0
                                                  : item.key == 4
                                                  ? constraints.maxWidth -
                                                        labelWidth
                                                  : constraints.maxWidth *
                                                            item.key /
                                                            4 -
                                                        labelWidth / 2,
                                              width: labelWidth,
                                              height: 22,
                                              child: FittedBox(
                                                key: Key(
                                                  'dailyTimingAxis${item.key}',
                                                ),
                                                alignment: item.key == 0
                                                    ? Alignment.centerLeft
                                                    : item.key == 4
                                                    ? Alignment.centerRight
                                                    : Alignment.center,
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  item.value,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: BronzePalette.muted,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (nowFraction != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Align(
                                      alignment: Alignment(
                                        nowFraction * 2 - 1,
                                        0,
                                      ),
                                      child: Text(
                                        '${local('Now', 'இப்போது')} · ${widget.clock(now)}',
                                        key: const Key('dailyTimingNow'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: BronzePalette.gold,
                                        ),
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  height: 45,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    key: const Key('dailyTiming24hLanes'),
                                    painter: DailyTimingLanePainter(
                                      focus: widget.focus?.lane(widget.date),
                                      caution: widget.caution?.lane(
                                        widget.date,
                                      ),
                                      now: nowFraction,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        _window(
                          local(
                            'Focus on important things',
                            'முக்கிய விஷயத்தில் கவனம்',
                          ),
                          widget.focusRange,
                          local(
                            'Focus on work or important conversations.',
                            'வேலை அல்லது முக்கிய உரையாடலில் கவனம் செலுத்துங்கள்.',
                          ),
                          BronzePalette.gold,
                        ),
                        const SizedBox(height: 13),
                        _window(
                          local(
                            'Take things slowly',
                            'சற்று நிதானமாக இருங்கள்',
                          ),
                          widget.cautionRange,
                          local(
                            'Take your time before a big decision.',
                            'முக்கிய முடிவை எடுக்கும் முன் நிதானமாக யோசியுங்கள்.',
                          ),
                          BronzePalette.avoid,
                        ),
                        if (widget.overlap != null)
                          Container(
                            margin: const EdgeInsets.only(top: 13),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: BronzePalette.raised,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.overlap!,
                              key: const Key('dailyTimingOverlap'),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: BronzePalette.gold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          widget.city,
                          style: const TextStyle(
                            fontSize: 12,
                            color: BronzePalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    local(
                      widget.tomorrow
                          ? 'What to focus on tomorrow'
                          : 'What to focus on today',
                      widget.tomorrow
                          ? 'நாளை எதில் கவனம் செலுத்தலாம்'
                          : 'இன்று எதில் கவனம் செலுத்தலாம்',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: BronzePalette.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (widget.guidance.isEmpty)
                    Text(
                      local(
                        'Reading unavailable. Please retry from Daily.',
                        'பலன் கிடைக்கவில்லை. தினசரி பக்கத்தில் மீண்டும் முயற்சிக்கவும்.',
                      ),
                      style: const TextStyle(color: BronzePalette.muted),
                    )
                  else
                    for (final point in widget.guidance)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.check,
                                size: 15,
                                color: BronzePalette.gold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  height: 1.65,
                                  color: BronzePalette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          FilledButton.icon(
            key: const Key('dailyTimingShare'),
            onPressed: _sharing ? null : _share,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(
              local(
                widget.tomorrow
                    ? 'Share tomorrow’s guide'
                    : 'Share today’s guide',
                widget.tomorrow
                    ? 'நாளைய வழிகாட்டலைப் பகிருங்கள்'
                    : 'இன்றைய வழிகாட்டலைப் பகிருங்கள்',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _window(String label, String range, String hint, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Icon(Icons.circle, color: color, size: 8),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: BronzePalette.ink)),
            const SizedBox(height: 2),
            Text(
              range,
              style: const TextStyle(fontSize: 13, color: BronzePalette.gold),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(
                height: 1.6,
                fontSize: 13,
                color: BronzePalette.muted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class DailyTimingLanePainter extends CustomPainter {
  const DailyTimingLanePainter({this.focus, this.caution, this.now});
  final ({double start, double end})? focus, caution;
  final double? now;

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in [
      (focus, BronzePalette.gold, 0.0),
      (caution, BronzePalette.avoid, 26.0),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, item.$3, size.width, 19),
          const Radius.circular(5),
        ),
        Paint()..color = BronzePalette.border.withValues(alpha: .45),
      );
      final range = item.$1;
      if (range == null) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            range.start * size.width,
            item.$3,
            (range.end - range.start) * size.width,
            19,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = item.$2,
      );
    }
    if (now != null) {
      canvas.drawLine(
        Offset(now! * size.width, 0),
        Offset(now! * size.width, size.height),
        Paint()
          ..color = BronzePalette.ink
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DailyTimingLanePainter oldDelegate) =>
      focus != oldDelegate.focus ||
      caution != oldDelegate.caution ||
      now != oldDelegate.now;
}
