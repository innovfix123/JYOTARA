import 'dart:io';

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
          const AssetImage('assets/images/jyotara_rasi_logo.png'),
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
          '/Users/apple/Documents/Startup/source/jyotara/docs/qa/2026-10-07/onboarding120/${login ? 'login' : 'birth-form'}-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
