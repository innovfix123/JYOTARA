import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/bronze_theme.dart';
import 'package:jyotara/cinematic_matching.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/matching_art.dart';
import 'package:jyotara/rasi_emblem.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/matching_rasi.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    accountStorage.account = null;
  });
  test(
    'cinematic keeps the approved finite camera/arrow/heart choreography',
    () {
      const s = Size(348, 310.7);
      expect(MatchingMotionFrame(0, s).phase, 'wide');
      expect(MatchingMotionFrame(1500, s).zoom, closeTo(2.08, .001));
      expect(MatchingMotionFrame(1800, s).phase, 'arrow-follow');
      final impact = MatchingMotionFrame(2600, s);
      expect(impact.arrow.dx, impact.target.dx);
      expect(impact.arrow.dy, impact.target.dy - 4);
      final end = MatchingMotionFrame(4900, s);
      expect(end.zoom, 1);
      expect(end.target.dx, closeTo(s.width * .39, .001));
      expect(end.second.dx, closeTo(s.width * .67, .001));
      expect(end.exit, 1);
      expect(matchingMotionDuration.inMilliseconds, 4900);
    },
  );
  testWidgets('each selected relationship has its exact approved asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MatchingScreen(loadKundlis: () async => [])),
    );
    await tester.pumpAndSettle();
    for (final type in matchingSceneAssets.keys) {
      await tester.ensureVisible(find.text(type));
      await tester.tap(find.text(type));
      await tester.pump();
      expect(
        tester.widget<MatchingSceneArt>(find.byType(MatchingSceneArt)).type,
        type,
      );
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(MatchingSceneArt),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as AssetImage).assetName, matchingSceneAssets[type]);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'both saved cards show their own chart sign, not a generic avatar',
    (tester) async {
      Future<SavedKundli> make(String name, String date, String rasi) async {
        final session = ProfileSession(
          api: JyotaraApiClient(
            baseUrl: 'https://test',
            client: MockClient((_) async {
              final payload =
                  jsonDecode(chartReply(name).body) as Map<String, dynamic>;
              payload['result']['data']['nakshatra_details']['chandra_rasi']['name'] =
                  rasi;
              return http.Response(jsonEncode(payload), 200);
            }),
          ),
        );
        await session.calculate(
          dateTime: '${date}T05:00:00+05:30',
          latitude: 11,
          longitude: 77,
          exactTime: true,
          nickname: name,
        );
        return SavedKundli(name, session);
      }

      final a = await make('Saran', '2002-07-29', 'Meena'),
          b = await make('Divya', '2001-05-18', 'Simha');
      await tester.pumpWidget(
        MaterialApp(home: MatchingScreen(loadKundlis: () async => [a, b])),
      );
      await tester.pumpAndSettle();
      for (final pair in [(true, a), (false, b)]) {
        await tester.ensureVisible(
          find.byKey(ValueKey(pair.$1 ? 'matching-first' : 'matching-second')),
        );
        await tester.tap(
          find.byKey(ValueKey(pair.$1 ? 'matching-first' : 'matching-second')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('matching-saved-${pair.$2.id}')));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widgetList<RasiEmblem>(find.byType(RasiEmblem))
            .map((e) => e.index)
            .toList(),
        [11, 4],
      );
      expect(find.text('Meena Rasi'), findsOneWidget);
      expect(find.text('Simha Rasi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      a.session.dispose();
      b.session.dispose();
    },
  );
  testWidgets(
    'late legacy chart response cannot replace a different selected person',
    (tester) async {
      final previous = Completer<String?>();
      final current = Completer<String?>();
      var calls = 0;
      final person = {
        'nickname': 'Divya',
        'datetime': '2001-05-18T08:30:00+05:30',
        'latitude': 11.0,
        'longitude': 77.0,
        'exactTime': true,
        'birthplaceLabel': 'Erode',
      };
      final second = {
        ...person,
        'nickname': 'Shakthi',
        'datetime': '2001-05-19T08:30:00+05:30',
      };
      FlutterSecureStorage.setMockInitialValues({
        'jyotara.matching.people.v1': jsonEncode([person, second]),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MatchingScreen(
            loadKundlis: () async => [],
            resolveRasi: (data) async {
              calls++;
              return calls == 1 ? previous.future : current.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('matching-second')));
      await tester.tap(find.byKey(const ValueKey('matching-second')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Divya'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('matching-second')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shakthi'));
      await tester.pumpAndSettle();
      current.complete('Karka');
      await tester.pumpAndSettle();
      previous.complete('Simha');
      await tester.pumpAndSettle();
      expect(calls, 2);
      // Each response is stamped with its own birth key. A former selection's
      // response cannot replace the currently selected person's actual sign.
      final stored = jsonDecode(
        (await const FlutterSecureStorage().read(
          key: 'jyotara.matching.people.v1',
        ))!,
      ) as List;
      for (final row in stored) {
        expect(
          row['rasiBirthKey'],
          matchingBirthKey(Map<String, dynamic>.from(row)),
        );
      }
      expect(stored.length, 2);
      final card = find.byKey(const ValueKey('matching-second'));
      await tester.ensureVisible(card);
      expect(
        tester
            .widget<RasiEmblem>(
              find.descendant(of: card, matching: find.byType(RasiEmblem)),
            )
            .index,
        3,
      );

      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reduced motion shows final hearts and cancels cleanly on removal',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: CinematicMatchingAnimation(
                first: 'A',
                second: 'B',
                type: 'My Crush',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your connection is ready'), findsWidgets);
      expect(tester.hasRunningAnimations, false);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('approved native frame records and all twelve atlas windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 830);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final f in {
        'JyotaraEditorial': 'Inter-Regular',
        'JyotaraSans': 'Inter-Regular',
      }.entries) {
        await (FontLoader(
          f.key,
        )..addFont(rootBundle.load('assets/fonts/${f.value}.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final boundary = GlobalKey();
    final output = Directory('../../docs/qa/2026-10-08/cinematic139')
      ..createSync(recursive: true);
    Future<void> capture(String name) async {
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/native-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    final theme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: BronzePalette.background,
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'JyotaraSans'),
      colorScheme: const ColorScheme.dark(
        primary: BronzePalette.accent,
        surface: BronzePalette.card,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: boundary,
          child: const Scaffold(
            body: CinematicMatchingAnimation(
              first: 'Saran',
              second: 'Divya',
              type: 'My Partner',
              firstRasi: 11,
              secondRasi: 4,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final asset in [cupidAsset, matchingHeartAsset, rasiEmblemAsset]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(Scaffold)),
        );
      }
    });
    await tester.pump();
    var now = 0;
    for (final frame in [
      (400, 'wide'),
      (1500, 'bow'),
      (2200, 'flight'),
      (2800, 'impact'),
      (4400, 'pair'),
    ]) {
      await tester.pump(Duration(milliseconds: frame.$1 - now));
      now = frame.$1;
      await capture(frame.$2);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Center(
              child: Wrap(
                children: [
                  for (var i = 0; i < 12; i++) RasiEmblem(index: i, size: 94),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('rasi-gallery');
  });
}
