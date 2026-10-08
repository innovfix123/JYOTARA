import 'dart:io';

import 'package:jyotara/chat_wallpaper.dart';

import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  for (final login in [false, true]) {
    testWidgets('onboarding ${login ? 'login' : 'birth'} visual preview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final f in {
        'JyotaraEditorial': 'CormorantGaramond',
        'JyotaraSans': 'Manrope',
      }.entries) {
        final loader = FontLoader(f.key)
          ..addFont(rootBundle.load('assets/fonts/${f.value}.ttf'));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: login
                ? PhoneAccessScreen(
                    access: PhoneAccess(
                      testerCode: () => null,
                      read: () async => null,
                      write: (_) async {},
                    ),
                    child: const Text('Home'),
                  )
                : BirthForm(onboarding: true, session: ProfileSession()),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await precacheImage(
          const AssetImage('assets/images/onboarding_mountains119.png'),
          key.currentContext!,
        );
        await precacheImage(
          const AssetImage('assets/images/jyotara-zodiac-j140.png'),
          key.currentContext!,
        );
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/Users/apple/Documents/Startup/source/jyotara/docs/qa/2026-10-08/welcome140/${login ? 'login' : 'birth-form'}-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('faded chat wallpaper keeps messages and send controls usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    var tapped = false;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(title: const Text('Jyotara')),
            body: ChatWallpaper(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Welcome. What would you like to ask today?',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Row(
                      children: [
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Your question…',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => tapped = true,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/onboarding_mountains119.png'),
        key.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send));
    expect(tapped, true);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/Users/apple/Documents/Startup/source/jyotara/docs/qa/2026-10-08/welcome140/chat-wallpaper-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
