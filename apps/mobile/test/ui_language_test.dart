import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:jyotara/services/language_preferences.dart';
import 'package:jyotara/main.dart';

void main() {
  testWidgets(
    'app switches Tamil without losing the open page and localises date/time dialogs',
    (tester) async {
      final ui = UiLanguagePreferences(write: (_) async {});
      await tester.pumpWidget(JyotaraApp(uiPreferences: ui));
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.tap(find.byKey(const Key('enterApp')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Your account'), findsOneWidget);
      await ui.set('ta');
      await tester.pumpAndSettle();
      expect(find.text('உங்கள் கணக்கு'), findsOneWidget);
      await tester.tap(find.text('பிறப்பு விவரங்கள்'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gender-female')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('gender-continue')));
      await tester.tap(find.byKey(const ValueKey('gender-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('பிறந்த தேதி'));
      await tester.pumpAndSettle();
      final dateContext = tester.element(find.byType(DatePickerDialog));
      expect(Localizations.localeOf(dateContext).languageCode, 'ta');
      final cancel = MaterialLocalizations.of(dateContext).cancelButtonLabel;
      expect(cancel, isNot('Cancel'));
      expect(find.text(cancel), findsOneWidget);
      await tester.tap(find.text(cancel));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.text('சரியான பிறந்த நேரம்'),
        150,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('சரியான பிறந்த நேரம்'));
      await tester.pumpAndSettle();
      final timeContext = tester.element(find.byType(TimePickerDialog));
      expect(Localizations.localeOf(timeContext).languageCode, 'ta');
      expect(
        find.text(MaterialLocalizations.of(timeContext).cancelButtonLabel),
        findsOneWidget,
      );
    },
  );
  test(
    'UI preferences persist separately and do not accept Tanglish menus',
    () async {
      String? disk;
      final chat = LanguagePreferences(
        read: () async => 'tanglish',
        write: (_) async {},
      );
      await chat.load();
      final ui = UiLanguagePreferences(
        read: () async => disk,
        write: (v) async {
          disk = v;
        },
      );
      await ui.load();
      expect(ui.value, 'en');
      await ui.set('ta');
      expect(chat.value, 'tanglish');
      final restored = UiLanguagePreferences(
        read: () async => disk,
        write: (_) async {},
      );
      await restored.load();
      expect(restored.value, 'ta');
      await expectLater(ui.set('tanglish'), throwsArgumentError);
      expect(ui.value, 'ta');
      final failing = UiLanguagePreferences(
        write: (_) async {
          throw StateError('disk unavailable');
        },
      );
      await expectLater(failing.set('ta'), throwsStateError);
      expect(
        failing.value,
        'en',
        reason: 'Failed save must not claim preference was saved',
      );
    },
  );
  testWidgets('visible labels update without recreating the navigator', (
    tester,
  ) async {
    final ui = UiLanguagePreferences(write: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: UiLanguageScope(
          preferences: ui,
          child: Builder(
            builder: (context) =>
                Scaffold(body: Text(uiText(context, 'Account'))),
          ),
        ),
      ),
    );
    expect(find.text('Account'), findsOneWidget);
    await ui.set('ta');
    await tester.pump();
    expect(find.text('கணக்கு'), findsOneWidget);
    await ui.set('en');
    await tester.pump();
    expect(find.text('Account'), findsOneWidget);
  });
}
