import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  testWidgets(
    'tapping an already focused number field explicitly reopens dismissed keyboard',
    (tester) async {
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async => null,
        write: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneAccessScreen(access: access, child: const Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField).first;
      final focus = tester.widget<TextField>(field).focusNode!;
      expect(focus.hasFocus, true);
      tester.testTextInput.hide();
      expect(tester.testTextInput.isVisible, false);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pump();
      await tester.pump();
      expect(tester.testTextInput.isVisible, true);
      await tester.enterText(field, '98765');
      expect(tester.widget<TextField>(field).controller!.text, '98765');
      expect(access.codeSent, false);
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    },
  );
  testWidgets(
    'opening and closing the keyboard retains the live phone editor and focus',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async => null,
        write: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PhoneAccessScreen(access: access, child: const Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      await tester.enterText(find.byType(TextField).first, '98765');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        true,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '98765',
      );
      expect(tester.testTextInput.isVisible, true);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editor),
      );
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    },
  );
}
