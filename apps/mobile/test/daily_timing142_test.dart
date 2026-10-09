import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/daily_timing_data.dart';
import 'package:jyotara/daily_timing_guide.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/ui_language.dart';

Map<String, String> window(String start, String end) => {
  'start': '2026-10-09T$start:00+05:30',
  'end': '2026-10-09T$end:00+05:30',
};

class _Playback implements DailyTimingPlayback {
  final changes = ChangeNotifier();
  Completer<void>? initialization;
  bool initializeFails = false;
  int plays = 0, pauses = 0, disposals = 0;
  @override
  Duration position = Duration.zero;
  @override
  bool completed = false;
  @override
  bool failed = false;
  @override
  Future<void> initialize() async {
    if (initializeFails) throw StateError('Decoder unavailable');
    await initialization?.future;
  }

  @override
  Future<void> play() async => plays++;
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> dispose() async => disposals++;
  @override
  void addListener(VoidCallback listener) => changes.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      changes.removeListener(listener);
  @override
  Widget view() => const SizedBox(key: Key('suppliedAnimation'));
  void advance(Duration value) {
    position = value;
    changes.notifyListeners();
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('24-hour lanes keep minute precision and clip at midnight', () {
    final focus = DailyTimingWindow.fromProvider(window('11:43', '12:30'))!;
    final lane = focus.lane('2026-10-09')!;
    expect(lane.start, closeTo(703 / 1440, .00000001));
    expect(lane.end, closeTo(750 / 1440, .00000001));
    final overnight = DailyTimingWindow.fromProvider({
      'start': '2026-10-08T23:30:00+05:30',
      'end': '2026-10-09T01:15:00+05:30',
    })!;
    expect(overnight.lane('2026-10-09'), (start: 0.0, end: 75 / 1440));
    expect(focus.lane('2026-10-10'), isNull);
  });

  test(
    'actual windows overlap only with shared time, never touching endpoints',
    () {
      final focus = DailyTimingWindow.fromProvider(window('11:43', '12:30'))!;
      expect(
        focus.overlaps(
          DailyTimingWindow.fromProvider(window('10:37', '12:06'))!,
        ),
        isTrue,
      );
      expect(
        focus.overlaps(
          DailyTimingWindow.fromProvider(window('12:30', '13:00'))!,
        ),
        isFalse,
      );
      for (final invalid in [
        null,
        {},
        window('13:00', '12:30'),
        {'start': 'invalid', 'end': 'invalid'},
      ]) {
        expect(DailyTimingWindow.fromProvider(invalid), isNull);
      }
    },
  );

  test('Now follows the selected Indian date and hides outside that day', () {
    expect(
      DailyTimingWindow.nowFraction(
        '2026-10-09',
        DateTime.parse('2026-10-09T12:08:00+05:30'),
      ),
      closeTo(728 / 1440, .00000001),
    );
    expect(
      DailyTimingWindow.nowFraction(
        '2026-10-10',
        DateTime.parse('2026-10-09T12:08:00+05:30'),
      ),
      isNull,
    );
    expect(
      DailyTimingWindow.nowFraction(
        '2026-10-09',
        DateTime.parse('2026-10-10T00:00:00+05:30'),
      ),
      isNull,
    );
  });

  Widget flow(
    _Playback playback, {
    bool reduced = false,
    void Function(String, int)? event,
  }) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: DailyTimingExperience(
                  title: 'Today’s timings',
                  tamil: false,
                  playbackFactory: () => playback,
                  onVideoEvent: event,
                  guideBuilder: (_) => const Text(
                    'Actual day guide',
                    key: Key('destinationGuide'),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('See your day'),
        ),
      ),
    ),
  );

  testWidgets(
    'click plays once, guide opens only at eight seconds, back disposes',
    (tester) async {
      final playback = _Playback();
      final events = <String>[];
      await tester.pumpWidget(
        flow(playback, event: (outcome, _) => events.add(outcome)),
      );
      expect(playback.plays, 0);
      await tester.tap(find.text('See your day'));
      await tester.pumpAndSettle();
      expect(playback.plays, 1);
      expect(find.byKey(const Key('suppliedAnimation')), findsOneWidget);
      playback.advance(const Duration(milliseconds: 7999));
      await tester.pump();
      expect(find.byKey(const Key('destinationGuide')), findsNothing);
      playback.advance(const Duration(seconds: 8));
      await tester.pump();
      expect(find.byKey(const Key('destinationGuide')), findsOneWidget);
      expect(playback.disposals, 1);
      await tester.pump(const Duration(seconds: 15));
      expect(playback.plays, 1);
      expect(events, ['started', 'success']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('See your day'), findsOneWidget);
      expect(playback.disposals, 1);
    },
  );

  testWidgets(
    'skip while initializing opens guide and late initialization cannot play',
    (tester) async {
      final playback = _Playback()..initialization = Completer<void>();
      await tester.pumpWidget(flow(playback));
      await tester.tap(find.text('See your day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('dailyTimingSkip')));
      await tester.pump();
      playback.initialization!.complete();
      await tester.pump();
      expect(find.byKey(const Key('destinationGuide')), findsOneWidget);
      expect(playback.plays, 0);
      expect(playback.disposals, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduced motion reaches guide without creating or playing a video',
    (tester) async {
      final playback = _Playback();
      await tester.pumpWidget(flow(playback, reduced: true));
      await tester.tap(find.text('See your day'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destinationGuide')), findsOneWidget);
      expect(playback.plays, 0);
      expect(playback.disposals, 0);
    },
  );

  testWidgets('unavailable video reaches data and does not loop', (
    tester,
  ) async {
    final playback = _Playback()..initializeFails = true;
    await tester.pumpWidget(flow(playback));
    await tester.tap(find.text('See your day'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('destinationGuide')), findsOneWidget);
    expect(find.textContaining('Video unavailable'), findsOneWidget);
    expect(playback.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'background pauses and resumes existing position; stalled video has fallback',
    (tester) async {
      final playback = _Playback();
      await tester.pumpWidget(flow(playback));
      await tester.tap(find.text('See your day'));
      await tester.pumpAndSettle();
      playback.advance(const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(playback.pauses, 1);
      expect(find.byKey(const Key('destinationGuide')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(playback.plays, 2);
      expect(playback.position, const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 13));
      expect(find.byKey(const Key('destinationGuide')), findsOneWidget);
      expect(playback.disposals, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final language in ['en', 'ta']) {
    testWidgets(
      'compact card opens actual locale timings and provider guidance in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = UiLanguagePreferences(write: (_) async {});
        await prefs.set(language);
        final tamil = language == 'ta';
        await tester.pumpWidget(
          UiLanguageScope(
            preferences: prefs,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: child!,
              ),
              home: MediaQuery(
                data: const MediaQueryData(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(1.3),
                ),
                child: DailyHoroscopeScreen(
                  readCity: () async => jsonEncode({
                    'name': 'Chennai',
                    'lat': 13.08,
                    'lon': 80.27,
                  }),
                  request: (path, body) async => {
                    'sections': [
                      {
                        'title': 'General',
                        'text': tamil
                            ? 'இன்று மெதுவாகச் செயல்படுங்கள். மற்றொரு வாக்கியம்.'
                            : 'Provider general guidance. Another sentence.',
                      },
                      {
                        'title': 'Career',
                        'text': tamil
                            ? 'வேலையில் கவனம் செலுத்துங்கள்.'
                            : 'Provider career guidance.',
                      },
                    ],
                    'timings': [
                      {
                        'name': 'Abhijit Muhurta',
                        'start': '${body['date']}T11:43:00+05:30',
                        'end': '${body['date']}T12:30:00+05:30',
                      },
                      {
                        'name': 'Rahu Kalam',
                        'start': '${body['date']}T10:37:00+05:30',
                        'end': '${body['date']}T12:06:00+05:30',
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.byKey(const Key('dailyApprovedLotus')), findsOneWidget);
        expect(find.byKey(const Key('dailyTiming24hLanes')), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('dailySeeYourDay')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('dailySeeYourDay')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dailyTiming24hLanes')), findsOneWidget);
        expect(find.byKey(const Key('dailyTimingOverlap')), findsOneWidget);
        expect(find.textContaining('11:43'), findsOneWidget);
        expect(find.textContaining('10:37'), findsOneWidget);
        expect(
          find.text(
            tamil
                ? 'இன்று மெதுவாகச் செயல்படுங்கள்.'
                : 'Provider general guidance.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            tamil
                ? 'வேலையில் கவனம் செலுத்துங்கள்.'
                : 'Provider career guidance.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(tamil ? 'மற்றொரு வாக்கியம்' : 'Another sentence'),
          findsNothing,
        );
        expect(find.text(tamil ? 'சென்னை' : 'Chennai'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'early reduced-motion guide waits for restored city and delayed provider data',
    (tester) async {
      final restore = Completer<String?>();
      final reading = Completer<Map<String, dynamic>>();
      final calendar = Completer<Map<String, dynamic>>();
      String? requestedDate;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: DailyHoroscopeScreen(
            readCity: () => restore.future,
            request: (path, body) {
              requestedDate = '${body['date']}';
              return path == '/api/horoscope/daily'
                  ? reading.future
                  : calendar.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('dailySeeYourDay')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('dailySeeYourDay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('dailyTimingGuideLoading')), findsOneWidget);
      expect(find.byKey(const Key('dailyTimingGuide')), findsNothing);
      restore.complete(
        jsonEncode({'name': 'Chennai', 'lat': 13.08, 'lon': 80.27}),
      );
      await tester.pump();
      calendar.complete({
        'timings': [
          {
            'name': 'Abhijit Muhurta',
            'start': '${requestedDate}T11:43:00+05:30',
            'end': '${requestedDate}T12:30:00+05:30',
          },
          {
            'name': 'Rahu Kalam',
            'start': '${requestedDate}T10:37:00+05:30',
            'end': '${requestedDate}T12:06:00+05:30',
          },
        ],
      });
      await tester.pump();
      expect(find.byKey(const Key('dailyTimingGuideLoading')), findsOneWidget);
      reading.complete({
        'sections': [
          {
            'title': 'General',
            'text': 'Delayed provider guidance. More details.',
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dailyTimingGuideLoading')), findsNothing);
      expect(find.byKey(const Key('dailyTimingGuide')), findsOneWidget);
      expect(find.text('11:43 AM–12:30 PM'), findsOneWidget);
      expect(find.text('10:37 AM–12:06 PM'), findsOneWidget);
      expect(find.text('Delayed provider guidance.'), findsOneWidget);
      expect(find.text('Chennai'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'separate lanes preserve overlap and tomorrow omits Now; sharing uses rendered guide',
    (tester) async {
      MethodCall? shared;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('jyotara/couple-share'),
        (call) async {
          shared = call;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('jyotara/couple-share'),
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyTimingGuide(
              date: '2026-10-10',
              tomorrow: true,
              tamil: false,
              city: 'Chennai',
              focus: DailyTimingWindow.fromProvider({
                'start': '2026-10-10T11:43:00+05:30',
                'end': '2026-10-10T12:30:00+05:30',
              }),
              caution: DailyTimingWindow.fromProvider({
                'start': '2026-10-10T10:37:00+05:30',
                'end': '2026-10-10T12:06:00+05:30',
              }),
              focusRange: '11:43 AM–12:30 PM',
              cautionRange: '10:37 AM–12:06 PM',
              overlap: null,
              guidance: const ['Provider supplied guidance.'],
              clock: (_) => '12:08 PM',
              now: () => DateTime.parse('2026-10-09T12:08:00+05:30'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dailyTimingNow')), findsNothing);
      expect(find.byKey(const Key('dailyTimingOverlap')), findsNothing);
      expect(find.text('What to focus on tomorrow'), findsOneWidget);
      final lanes =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('dailyTiming24hLanes')),
                  )
                  .painter!
              as DailyTimingLanePainter;
      expect(lanes.focus!.start, closeTo(703 / 1440, .00000001));
      expect(lanes.caution!.end, closeTo(726 / 1440, .00000001));
      expect(lanes.focus!.start, lessThan(lanes.caution!.end));
      final axis = tester.getRect(find.byKey(const Key('dailyTimingAxis')));
      expect(
        tester.getCenter(find.byKey(const Key('dailyTimingAxis1'))).dx,
        closeTo(axis.left + axis.width * .25, .01),
      );
      expect(
        tester.getCenter(find.byKey(const Key('dailyTimingAxis3'))).dx,
        closeTo(axis.left + axis.width * .75, .01),
      );
      await tester.ensureVisible(find.byKey(const Key('dailyTimingShare')));
      await tester.tap(find.byKey(const Key('dailyTimingShare')));
      for (var i = 0; i < 30 && shared == null; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(shared, isNotNull);
      expect(shared!.method, 'share');
      expect(shared!.arguments['animated'], isFalse);
      expect(shared!.arguments['frames'], hasLength(1));
      expect(shared!.arguments.keys, isNot(contains('name')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
