import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/launch_intro.dart';

void main() {
  testWidgets('intro waits for restored state then reveals the destination', (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: LaunchIntro(
      initialization: ready.future, child: const Text('Destination'),
    )));
    expect(find.text('Jyotara'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Destination'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsOneWidget);
  });
  testWidgets('reduced motion skips animation but still waits for restoration', (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: LaunchIntro(initialization: ready.future, child: const Text('Ready')),
    )));
    expect(find.text('Ready'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });
}
