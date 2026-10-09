import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/ask_theme.dart';
import 'package:jyotara/bronze_theme.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/ui_language.dart';

void main() {
  for (final language in ['en', 'ta']) {
    for (final conversation in [false, true]) {
      testWidgets(
        'Soft Bronze native ${conversation ? 'chat' : 'Ask'} $language',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            for (final entry in {
              'JyotaraSans': 'Inter',
              'JyotaraEditorial': 'Inter',
              'JyotaraChat': 'Roboto',
              'JyotaraTamil': 'NotoSansTamil',
            }.entries) {
              final loader = FontLoader(entry.key);
              for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
                loader.addFont(
                  rootBundle.load('assets/fonts/${entry.value}-$weight.ttf'),
                );
              }
              await loader.load();
            }
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
          final languagePreference = UiLanguagePreferences(write: (_) async {});
          await languagePreference.set(language);
          final session = ProfileSession();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: BronzePalette.background,
                ),
                builder: (context, child) => UiLanguageScope(
                  preferences: languagePreference,
                  child: child!,
                ),
                home: conversation
                    ? ChatScreen(guide: guides.first, session: session)
                    : const MainShell(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (!conversation) {
            await tester.tap(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(language == 'ta' ? 'கேளுங்கள்' : 'Ask'),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              Theme.of(tester.element(find.byType(NavigationBar)))
                  .scaffoldBackgroundColor,
              AskPalette.background,
            );
          }
          await tester.runAsync(() async {
            await precacheImage(
              const AssetImage('assets/images/guides_portraits97.png'),
              boundary.currentContext!,
            );
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final rendered =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await rendered.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '${Directory.current.path}/../../docs/qa/2026-10-09/ask142/${conversation ? 'chat' : 'ask'}-$language.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (!conversation) {
            await tester.tap(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(language == 'ta' ? 'முகப்பு' : 'Home'),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              Theme.of(tester.element(find.byType(NavigationBar)))
                  .scaffoldBackgroundColor,
              BronzePalette.background,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          session.dispose();
        },
      );
    }
  }
}
