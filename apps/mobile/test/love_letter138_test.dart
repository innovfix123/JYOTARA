import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/bronze_theme.dart';
import 'package:jyotara/rasi_emblem.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'automatic Rasi replaces the picker and matching remains readable in Tamil',
    (tester) async {
      final prefs = UiLanguagePreferences(write: (_) async {});
      await prefs.set('ta');
      await profileAvatarPreference.load();
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: prefs,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: AccountScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profileRasi')), findsOneWidget);
      expect(find.text('Choose avatar'), findsNothing);
      expect(find.byType(RasiEmblem), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        UiLanguageScope(
          preferences: prefs,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: MatchingScreen(loadKundlis: () async => []),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matchingSceneArt')), findsOneWidget);
      expect(find.text('உங்கள் மனதில் யார்?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('native approved Home Matching and Profile visual record', (
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
    final output = Directory('../../docs/qa/2026-10-08/cinematic139')
      ..createSync(recursive: true);
    final boundary = GlobalKey();
    for (final row in [
      ('matching', MatchingScreen(loadKundlis: () async => [])),
      ('profile', const Scaffold(body: AccountScreen())),
      ('home', Scaffold(body: HomeScreen(onOpenChat: (_) {}))),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: BronzePalette.background,
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'JyotaraSans',
            ),
            colorScheme: ColorScheme.dark(
              primary: BronzePalette.accent,
              surface: BronzePalette.card,
            ),
          ),
          home: RepaintBoundary(key: boundary, child: row.$2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/matching-love-letter138.png'),
          tester.element(find.byType(RepaintBoundary).first),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/native-${row.$1}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
