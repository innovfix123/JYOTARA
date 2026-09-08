import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/ui_language.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';

void main() {
  testWidgets(
    'Tamil device-deletion disclosure is explicit, cancellable and requires confirmation',
    (tester) async {
      var deletes = 0;
      final deletion = Completer<void>();
      final session = ProfileSession(
        vault: LocalProfileVault(
          read: () async => null,
          write: (value) async {
            if (value == null) deletes++;
            await deletion.future;
          },
        ),
      );
      // Retry-deletion state also needs accessible controls when no chart is open.
      session.storageError = 'Device deletion failed. Saved data may return after restart. Please retry deletion.';
      final ui = UiLanguagePreferences(write: (_) async {});
      await ui.set('ta');
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              UiLanguageScope(preferences: ui, child: child!),
          home: Scaffold(body: ChartScreen(session: session)),
        ),
      );
      expect(find.text('உங்கள் வேத ஜாதகம்'), findsOneWidget);
      final deleteLabel = tamilUi['Delete device profile and history']!;
      await tester.ensureVisible(find.text(deleteLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(deleteLabel));
      await tester.pumpAndSettle();
      expect(
        find.text(
          tamilUi['This deletes the saved chart and chat history from this device. It does not delete server usage records.']!,
        ),
        findsOneWidget,
      );
      expect(deletes, 0);
      await tester.tap(find.text('ரத்து'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(session.storageError, isNotNull);
      await tester.tap(find.text(deleteLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('நீக்கவும்'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(session.storageError, isNotNull);
      expect(find.text(tamilUi['Deleting data…']!), findsOneWidget);
      deletion.complete();
      await tester.pumpAndSettle();
      expect(session.storageError, null);
      expect(find.text(deleteLabel), findsNothing);
    },
  );
}
