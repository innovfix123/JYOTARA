import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/bronze_theme.dart';

void main() {
  testWidgets(
    'compact guide rows remain readable at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Guide? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: GuidesScreen(onOpenChat: (g) => selected = g),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('guide-card-Meera'));
      await tester.ensureVisible(card);
      expect(tester.getSize(card).height, lessThan(125));
      await tester.tap(find.text('Meera'));
      expect(selected?.name, 'Meera');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile uses live details inside the Bronze Eclipse card', (
    tester,
  ) async {
    profileSession.nickname = 'Saran';
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AccountScreen())),
    );
    await tester.pumpAndSettle();
    final card = tester.widget<Container>(
      find.byKey(const Key('bronzeProfileCard')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, BronzePalette.card);
    expect(find.text('Saran'), findsOneWidget);
    expect(find.text('Birth date'), findsOneWidget);
    expect(find.text('Birth time'), findsOneWidget);
    expect(find.text('Birth place'), findsOneWidget);
    expect(find.text('Edit birth details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    profileSession.nickname = '';
  });
}
