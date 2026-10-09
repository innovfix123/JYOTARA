import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/daily_timing_guide.dart';

class Playback extends ChangeNotifier implements DailyTimingPlayback {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  Duration get position => Duration.zero;
  @override
  bool get completed => false;
  @override
  bool get failed => false;
  @override
  Widget view() =>
      const ColoredBox(key: Key('full-video'), color: Colors.amber);
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('video fills viewport at width $width and skip reaches guide', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: DailyTimingExperience(
            title: 'Today’s timings',
            tamil: false,
            playbackFactory: Playback.new,
            guideBuilder: (_) => const Text('Real guide'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester.getRect(find.byKey(const Key('full-video'))),
        Rect.fromLTWH(0, 0, width, 844),
      );
      expect(find.byType(AppBar), findsNothing);
      await tester.tap(find.byKey(const Key('dailyTimingSkip')));
      await tester.pumpAndSettle();
      expect(find.text('Real guide'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
