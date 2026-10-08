import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'bronze_theme.dart';
import 'services/ui_language.dart';

const approvedWelcomeAsset = 'assets/videos/jyotara-welcome140.mp4';
const approvedWelcomePoster = 'assets/images/welcome-poster140.png';

/// Fill ordinary portrait phones while keeping the central title area intact.
/// Very wide or unusually narrow windows retain the complete approved frame.
Rect welcomeFrameBounds(Size viewport, double aspectRatio) {
  if (viewport.isEmpty || aspectRatio <= 0) return Offset.zero & viewport;
  final ratio = viewport.width / viewport.height;
  final cover = ratio <= aspectRatio && ratio >= aspectRatio * .64;
  final width = cover
      ? viewport.height * aspectRatio
      : ratio > aspectRatio
      ? viewport.height * aspectRatio
      : viewport.width;
  return Rect.fromCenter(
    center: viewport.center(Offset.zero),
    width: width,
    height: width / aspectRatio,
  );
}

class _WelcomeFrame extends StatelessWidget {
  const _WelcomeFrame({required this.aspectRatio, required this.child});
  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bounds = welcomeFrameBounds(constraints.biggest, aspectRatio);
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [Positioned.fromRect(rect: bounds, child: child)],
        ),
      );
    },
  );
}

/// The approved welcome is the only app intro. Restoration runs concurrently;
/// the destination retains its existing authentication and profile gates.
class CelestialWelcome extends StatefulWidget {
  const CelestialWelcome({
    super.key,
    required this.initialization,
    required this.child,
  });
  final Future<void>? initialization;
  final Widget child;

  @override
  State<CelestialWelcome> createState() => _CelestialWelcomeState();
}

class _CelestialWelcomeState extends State<CelestialWelcome>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  Timer? _deadline;
  bool _ready = false;
  bool _started = false;
  bool _finished = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    try {
      await widget.initialization;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Jyotara startup restoration',
        ),
      );
    }
    if (!mounted) return;
    setState(() => _ready = true);
    if (_finished) _releaseVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _finish();
    } else if (!_started) {
      _started = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final video = VideoPlayerController.asset(
      approvedWelcomeAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = video;
    video.addListener(_videoChanged);
    try {
      await video.initialize().timeout(const Duration(seconds: 3));
      if (!mounted || _finished) return;
      await video.setVolume(0);
      await video.setLooping(false);
      if (!mounted || _finished) return;
      setState(() {});
      if (_foreground) await _play();
    } catch (_) {
      // A decoder error must never trap the user on an opening screen.
      _finish();
    }
  }

  void _videoChanged() {
    final value = _video?.value;
    if (value == null || _finished) return;
    if (value.hasError || value.isCompleted) _finish();
  }

  Future<void> _play() async {
    final video = _video;
    if (video == null || !video.value.isInitialized || _finished) return;
    _deadline?.cancel();
    // Five-second local clip; a stalled decoder has a bounded fallback.
    _deadline = Timer(const Duration(seconds: 8), _finish);
    try {
      await video.play();
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _deadline?.cancel();
    final video = _video;
    if (video?.value.isInitialized == true) {
      unawaited(video!.pause().catchError((Object _) {}));
    }
    setState(() => _finished = true);
    if (_ready) _releaseVideo();
  }

  void _releaseVideo() {
    final video = _video;
    _video = null;
    if (video == null) return;
    video.removeListener(_videoChanged);
    unawaited(video.dispose());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_finished) return;
    if (_foreground) {
      unawaited(_play());
    } else {
      _deadline?.cancel();
      final video = _video;
      if (video?.value.isInitialized == true) {
        unawaited(video!.pause().catchError((Object _) {}));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    _releaseVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _finished) return widget.child;
    final video = _video;
    return Scaffold(
      key: const Key('celestialWelcome'),
      backgroundColor: BronzePalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: _WelcomeFrame(
              aspectRatio: 9 / 16,
              child: Image.asset(approvedWelcomePoster, fit: BoxFit.fill),
            ),
          ),
          if (video?.value.isInitialized == true)
            ExcludeSemantics(
              child: _WelcomeFrame(
                aspectRatio: video!.value.aspectRatio,
                child: VideoPlayer(video),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  key: const Key('skipWelcome'),
                  onPressed: _finished ? null : _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: BronzePalette.ink,
                    backgroundColor: BronzePalette.background.withValues(
                      alpha: .45,
                    ),
                  ),
                  child: const UiText('Skip'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
