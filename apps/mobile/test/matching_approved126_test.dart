import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/discovery_screens.dart';

const result = <String, dynamic>{
  'score': 18,
  'maximum': 36,
  'boyName': 'Arjun',
  'girlName': 'Meera',
  'connectionType': 'My Crush',
  'factors': <Map<String, dynamic>>[
    {
      'name': 'Your Conversations',
      'score': 2,
      'maximum': 3,
      'description': 'Give each other time to finish a thought.',
    },
  ],
};

void main() {
  test(
    'all twelve category illustrations are distinct bundled assets',
    () async {
      final assets = <String>{};
      for (final type in matchContexts) {
        for (var i = 0; i < 3; i++) {
          final path = matchAsset(type, i);
          assets.add(path);
          expect(
            (await rootBundle.load(path)).lengthInBytes,
            greaterThan(1000),
          );
        }
      }
      expect(assets.length, 12);
    },
  );
  testWidgets('three scenes play in order, reduced motion ends readably', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ApprovedMatchingAnimation(
            type: 'My Partner',
            first: 'A',
            second: 'B',
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('matching-sticker-0')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byKey(const ValueKey('matching-sticker-1')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.byKey(const ValueKey('matching-sticker-2')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Comparing your two charts…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'approved report uses server percentage, opens distinct studios and contains no quiz',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MatchingReport(value: result)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('78%'), findsNothing);
      expect(find.text('Couple Quiz'), findsNothing);
      expect(find.text('Our Story'), findsOneWidget);
      await tester.ensureVisible(find.text('Our Story'));
      await tester.tap(find.text('Our Story'));
      await tester.pumpAndSettle();
      expect(find.text('How did you meet?'), findsOneWidget);
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => (i.image as AssetImage).assetName)
          .toSet();
      expect(images.contains('assets/images/couple/story-0.webp'), true);
      expect(images.contains('assets/images/couple/story-2.webp'), true);
      expect(images.any((p) => p.contains('cards-')), false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('result and studio fit narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(child: MatchingReport(value: result)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: CoupleStudioScreen(value: result, kind: 'studio'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'photo share exports the rendered card after scrolling to the share buttons',
    (tester) async {
      MethodCall? shared;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('jyotara/couple-share'),
        (call) async {
          shared = call;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('jyotara/couple-share'),
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: CoupleStudioScreen(value: result, kind: 'studio'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview & share'));
      await tester.tap(find.text('Preview & share'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Photo card'));
      await tester.tap(find.text('Photo card'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('More sharing options'));
      await tester.tap(find.text('More sharing options'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(shared, isNotNull);
      expect(shared!.arguments['animated'], false);
      final bytes = shared!.arguments['frames'] as List;
      expect(bytes.length, 1);
      expect((bytes.first as List).take(8).toList(), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      expect(shared!.arguments.containsKey('datetime'), false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'animated sharing captures changing frames for a six-second story',
    (tester) async {
      MethodCall? shared;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('jyotara/couple-share'),
        (call) async {
          shared = call;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('jyotara/couple-share'),
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: CoupleStudioScreen(value: result, kind: 'day'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Make an invitation'));
      await tester.tap(find.text('Make an invitation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('More sharing options'));
      await tester.tap(find.text('More sharing options'));
      for (var i = 0; i < 100 && shared == null; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
      }
      expect(shared, isNotNull);
      expect(shared!.arguments['animated'], true);
      final frames = shared!.arguments['frames'] as List;
      expect(frames.length, 48);
      expect(frames[0], isNot(equals(frames[6])));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('native render of approved result for visual review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('JyotaraEditorial')
      ..addFont(rootBundle.load('assets/fonts/CormorantGaramond.ttf'));
    final sans = FontLoader('JyotaraSans')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    await sans.load();
    await tester.pumpWidget(
      const MaterialApp(
        home: MatchingSurface(
          child: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(22),
              child: MatchingReport(value: result),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/approved-matching126.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
