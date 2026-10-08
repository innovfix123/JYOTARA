import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/explore_screen.dart';
import 'package:jyotara/astrology_library.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/services/profile_session.dart';

class TicketApi extends AccountService {
  TicketApi()
    : super(token: () => 'test', tester: () => 'test', account: () => 'test');
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {
    'tickets': [
      {'id': 'review-1', 'category': 'app', 'status': 'open'},
    ],
  };
}

void main() {
  testWidgets(
    'Explore filters and search open real lessons rather than starting a paid chat',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExploreScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planets'));
      await tester.pumpAndSettle();
      expect(find.text('Understanding the 12 Rasis'), findsNothing);
      await tester.tap(find.text('The Nine Planets'));
      await tester.pumpAndSettle();
      expect(find.byType(AstrologyLessonPage), findsOneWidget);
      expect(find.text('The Navagraha'), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.tap(find.byTooltip('Search astrology'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'houses');
      await tester.pumpAndSettle();
      expect(find.text('Houses in Astrology'), findsOneWidget);
      expect(find.text('The Nine Planets'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Profile opened from Explore has Material text without fallback underlines',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExploreScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      final profile = find.byType(AccountScreen);
      expect(profile, findsOneWidget);
      final heading = find.descendant(
        of: profile,
        matching: find.text('Jyotara'),
      );
      final inherited = DefaultTextStyle.of(tester.element(heading)).style;
      final effective = inherited.merge(tester.widget<Text>(heading).style);
      expect(effective.color, const Color(0xFFF5EBD5));
      expect(effective.decoration, TextDecoration.none);
      expect(
        find.ancestor(of: heading, matching: find.byType(Material)),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Profile at large text retains support and privacy access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: AccountScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Privacy & account settings'),
      180,
    );
    await tester.tap(find.text('Privacy & account settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Wallet chat controls remain usable with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = ProfileSession();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: ChatScreen(guide: guides.first, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Detailed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('My Tickets opens saved requests without a new-ticket form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SupportScreen(api: TicketApi(), ticketsOnly: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reference: review-1'), findsOneWidget);
    expect(find.text('Submit request'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
