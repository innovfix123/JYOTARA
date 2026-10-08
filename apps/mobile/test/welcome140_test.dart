import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jyotara/bronze_theme.dart';
import 'package:jyotara/celestial_welcome.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/home_sage_art.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final calls = <String>[];
  DataSource? source;
  bool fail = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    source = dataSource;
    calls.add('create');
    if (fail) {
      events.addError(
        PlatformException(code: 'VideoError', message: 'Decoder unavailable'),
      );
    } else {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1080, 1920),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('loop:$looping');
  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume:$volume');
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const SizedBox(key: Key('approvedVideo'));
}

void main() {
  late _VideoPlatform platform;
  late VideoPlayerPlatform original;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    original = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = original;
    if (platform.source != null) {
      await platform.events.close();
    } else {
      unawaited(platform.events.close());
    }
  });

  Widget welcome({Future<void>? ready, bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: CelestialWelcome(
        initialization: ready,
        child: const Text('Home destination'),
      ),
    ),
  );
  Future<void> initialize(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('approved bundled clip completes once and enters restored Home', (
    tester,
  ) async {
    await tester.pumpWidget(welcome());
    await initialize(tester);
    expect(platform.source?.asset, approvedWelcomeAsset);
    expect(platform.calls, contains('volume:0.0'));
    expect(platform.calls, contains('loop:false'));
    expect(platform.calls.where((v) => v == 'play'), hasLength(1));
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.text('Ancient wisdom for a brighter you'), findsNothing);
    platform.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(platform.calls, contains('dispose'));
    expect(platform.calls.where((v) => v == 'play'), hasLength(1));
  });

  testWidgets('Skip never bypasses pending account restoration', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(welcome(ready: ready.future));
    await initialize(tester);
    await tester.tap(find.byKey(const Key('skipWelcome')));
    await tester.pump();
    expect(find.text('Home destination'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });

  testWidgets(
    'reduced motion creates no player and preserves restoration gate',
    (tester) async {
      final ready = Completer<void>();
      await tester.pumpWidget(welcome(ready: ready.future, reduced: true));
      expect(platform.calls, isEmpty);
      expect(find.text('Home destination'), findsNothing);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
    },
  );

  testWidgets('decoder failure falls through to the existing destination', (
    tester,
  ) async {
    platform.fail = true;
    await tester.pumpWidget(welcome());
    await initialize(tester);
    expect(find.text('Home destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'background pauses welcome without expiring its foreground deadline',
    (tester) async {
      await tester.pumpWidget(welcome());
      await initialize(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Home destination'), findsNothing);
      expect(platform.calls, contains('pause'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      platform.events.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
    },
  );

  testWidgets('stalled playback has a bounded fallback', (tester) async {
    await tester.pumpWidget(welcome());
    await initialize(tester);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });

  for (final language in ['en', 'ta']) {
    for (final width in [320.0, 384.0]) {
      testWidgets(
        'Home sage, chart naming and actions fit $language at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final languagePrefs = UiLanguagePreferences(write: (_) async {});
          await languagePrefs.set(language);
          await tester.pumpWidget(
            UiLanguageScope(
              preferences: languagePrefs,
              child: MaterialApp(
                home: Scaffold(body: HomeScreen(onOpenChat: (_) {})),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(HomeSageArt), findsOneWidget);
          expect(
            find.text(language == 'ta' ? 'ஜாதகம்' : 'Birth Chart'),
            findsOneWidget,
          );
          final ask = tester.getRect(find.byKey(const Key('homeGuideGroup')));
          final art = tester.getRect(find.byKey(const Key('homeSageArt')));
          expect(art.bottom, lessThan(ask.bottom));
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byKey(const Key('homeKundli')));
          await tester.tap(find.byKey(const Key('homeKundli')));
          await tester.pumpAndSettle();
          expect(find.byType(KundliLibraryScreen), findsOneWidget);
          expect(find.textContaining('Kundli'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Home visual record uses exact sage with readable copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final f in {
        'JyotaraEditorial': 'CormorantGaramond',
        'JyotaraSans': 'Manrope',
      }.entries) {
        await (FontLoader(
          f.key,
        )..addFont(rootBundle.load('assets/fonts/${f.value}.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final output = Directory('../../docs/qa/2026-10-08/welcome140')
      ..createSync(recursive: true);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: BronzePalette.background,
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'JyotaraSans',
          ),
        ),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(body: HomeScreen(onOpenChat: (_) {})),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(approvedSageAsset),
        tester.element(find.byType(HomeSageArt)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${output.path}/native-home.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
