import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';

void main() {
  testWidgets(
    'Midnight surfaces stay dark and reading text has sufficient contrast',
    (tester) async {
      tester.view.physicalSize = const Size(390,844); tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const JyotaraApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = app.theme!;
      expect(theme.brightness, Brightness.dark);
      for (final surface in [
        theme.scaffoldBackgroundColor,
        theme.cardTheme.color!,
        theme.inputDecorationTheme.fillColor!,
        theme.chipTheme.backgroundColor!,
      ]) {
        expect(surface.computeLuminance(), lessThan(.08));
        final contrast =
            (bodyInk.computeLuminance() + .05) /
            (surface.computeLuminance() + .05);
        expect(contrast, greaterThan(7));
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
