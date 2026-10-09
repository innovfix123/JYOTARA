import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';

import 'profile_replacement_test.dart' show chartReply;

class _Fixture {
  final calls = <Map<String, dynamic>>[];
  final replies = <Completer<http.Response>>[];
  String state = 'received';
  Completer<http.Response>? delayedStatus;
  String? disk;
  late final api = JyotaraApiClient(
    baseUrl: 'https://example.test',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/kundli')) {
        return chartReply('queue-profile');
      }
      final body = Map<String, dynamic>.from(jsonDecode(request.body));
      if (request.url.path.endsWith('/status')) {
        if (delayedStatus != null) return delayedStatus!.future;
        return http.Response(
          jsonEncode({
            'requestId': body['requestId'],
            'profileId': body['profileId'],
            'state': state,
          }),
          200,
        );
      }
      calls.add(body);
      final answer = Completer<http.Response>();
      replies.add(answer);
      return answer.future;
    }),
  );
  late final vault = LocalProfileVault(
    read: () async => disk,
    write: (value) async => disk = value,
  );
  late final session = ProfileSession(api: api, vault: vault);
  GuideConversation get chat =>
      session.conversation(guides.first.conversationKey);
  Future<void> open(WidgetTester tester) async {
    await session.calculate(
      dateTime: '2000-01-01T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(guide: guides.first, session: session),
      ),
    );
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('chatInput')), text);
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pump();
  }

  void answer(int index, [String text = 'First thought.\n\nSecond thought.']) =>
      replies[index].complete(
        http.Response(
          jsonEncode({
            'profileId': 'queue-profile',
            'answer': text,
            'answerMode': 'provider_reading',
            'evidence': [],
            'wallet': {
              'id': 'receipt-$index',
              'status': 'complete',
              'coins': 10,
            },
          }),
          200,
        ),
      );
  void terminalFailure(int index) => replies[index].complete(
    http.Response(
      jsonEncode({
        'profileId': 'queue-profile',
        'answer': 'Unavailable.',
        'answerMode': 'reading_unavailable',
        'evidence': [],
        'wallet': {'id': 'failure-$index', 'status': 'failed', 'coins': 0},
      }),
      200,
    ),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  }
}

void main() {
  testWidgets(
    'a confirmed failed reading lets a later queued turn proceed with its own ID',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'The first request.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await f.send(tester, 'A later different question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(f.calls, hasLength(1));
      f.terminalFailure(0);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(f.chat.turns.first.state, 'failed');
      expect(f.calls, hasLength(2));
      expect(f.calls.last['requestId'], isNot(f.calls.first['requestId']));
      expect(f.calls.last['question'], 'A later different question.');
      f.answer(1, 'A completed later answer.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'End and reopen can start fresh after a confirmed terminal failure',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'A terminally failed question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      final failedId = f.calls.single['requestId'];
      f.terminalFailure(0);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('end-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: f.session),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.chat.turns, isEmpty);
      expect(f.chat.history, hasLength(1));
      expect(
        f.calls,
        hasLength(1),
        reason: 'A fresh conversation does not replay the failed receipt',
      );
      await f.send(tester, 'A fresh question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(f.calls, hasLength(2));
      expect(f.calls.last['requestId'], isNot(failedId));
      f.answer(1, 'A fresh answer.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'ending and reopening an uncertain long batch preserves its explicit same-ID recovery',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, List.filled(170, 'a').join());
      await f.send(tester, List.filled(170, 'b').join());
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      final original = f.calls.single;
      expect((original['question'] as String).length, greaterThan(240));
      f.replies.first.complete(http.Response('{}', 503));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('end-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();
      expect(f.chat.ended, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: f.session),
        ),
      );
      await tester.pumpAndSettle();
      expect(f.chat.turns, hasLength(1));
      expect(f.chat.turns.single.state, 'uncertain');
      expect(
        f.calls,
        hasLength(1),
        reason:
            'Reopening a guide never automatically repeats uncertain paid work',
      );
      final retry = find.byKey(
        ValueKey('retry-turn-${f.chat.turns.single.id}'),
      );
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump();
      expect(f.calls, hasLength(2));
      expect(f.calls.last['requestId'], original['requestId']);
      expect(f.calls.last['userMessageBatch'], original['userMessageBatch']);
      f.answer(1, 'Recovered once.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  test('failed receipt preserves research consent and context for same-ID explicit reopening', () async {
    final f = _Fixture();
    await f.session.calculate(
      dateTime: '2000-01-01T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    f.session.setResearchConsent(true);
    final turn = ChatTurn(id: 'c' * 32, language: 'english', state: 'sending')
      ..messageIds.add('d' * 32)
      ..userMessages.add('A failed reading.');
    f.chat.turns.add(turn);
    f.chat.messages.add(
      ChatMessage(
        fromUser: true,
        text: turn.question,
        clientId: turn.messageIds.single,
      ),
    );
    Future<GuidanceResponse> ask() => f.session.ask(
      category: guides.first.category,
      question: turn.question,
      responseStyle: 'english',
      guide: guides.first.name,
      conversationKey: guides.first.conversationKey,
      userMessageBatch: turn.userMessages,
      clientRequestId: turn.id,
    );
    final pending = ask();
    await Future<void>.delayed(Duration.zero);
    f.replies.first.complete(
      http.Response(
        jsonEncode({
          'profileId': 'queue-profile',
          'answer': 'Unavailable.',
          'answerMode': 'reading_unavailable',
          'evidence': [],
          'wallet': {'id': 'failure', 'status': 'failed', 'coins': 0},
        }),
        200,
      ),
    );
    await f.session.recordGuidanceResponse(await pending, f.chat, 'english');
    expect(turn.state, 'failed');
    final original = f.calls.single;
    expect(original['researchConsentVersion'], 'research-conversation-v2');
    f.session.setResearchConsent(false);
    final retry = ask();
    await Future<void>.delayed(Duration.zero);
    expect(f.calls.last['requestId'], original['requestId']);
    expect(f.calls.last['researchConsent'], isTrue);
    expect(
      f.calls.last['researchConsentVersion'],
      original['researchConsentVersion'],
    );
    expect(
      f.calls.last['conversationHistory'],
      original['conversationHistory'],
    );
    f.answer(1, 'Reopened fixture result.');
    await f.session.recordGuidanceResponse(await retry, f.chat, 'english');
    expect(
      f.chat.messages.where(
        (message) => !message.fromUser && message.clientId == turn.id,
      ),
      hasLength(1),
    );
    f.session.dispose();
    f.api.close();
  });

  testWidgets(
    'a legacy 144 uncertain receipt keeps its original body and ID after upgrade',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      final initial = f.session.ask(
        category: guides.first.category,
        question: 'Legacy pending question.',
        responseStyle: 'english',
        guide: guides.first.name,
        conversationKey: guides.first.conversationKey,
      );
      final failed = expectLater(initial, throwsA(isA<JyotaraApiException>()));
      await tester.pump();
      f.replies.first.complete(http.Response('{}', 503));
      await failed;
      final original = f.calls.single;
      await f.send(tester, 'Legacy pending question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(f.calls, hasLength(2));
      expect(f.calls.last['requestId'], original['requestId']);
      expect(
        f.calls.last.containsKey('userMessageBatch'),
        isFalse,
        reason: 'Changing a legacy receipt payload would conflict with its original hash',
      );
      expect(
        f.calls.last['conversationHistory'],
        original['conversationHistory'],
      );
      f.answer(1, 'Recovered legacy answer.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'double tap and keyboard submit keep one submitted bubble and one request',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'One deliberate message.',
      );
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(f.chat.messages.where((m) => m.fromUser), hasLength(1));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(f.calls, hasLength(1));
      f.answer(0, 'Ready.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'late acknowledgment cannot color another queued turn or regress a completed receipt',
    (tester) async {
      final f = _Fixture()..delayedStatus = Completer<http.Response>();
      await f.open(tester);
      await f.send(tester, 'First request.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(
        f.chat.turns.first.ack,
        'sent',
        reason: 'Transport alone never claims server receipt',
      );
      f.answer(0, 'Ready.');
      await tester.pump();
      await tester.pump();
      await f.send(tester, 'A different queued message.');
      f.delayedStatus!.complete(
        http.Response(
          jsonEncode({
            'requestId': f.calls.first['requestId'],
            'profileId': 'queue-profile',
            'state': 'processing',
          }),
          200,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(f.chat.turns.first.ack, 'complete');
      expect(f.chat.turns.last.ack, 'queued');
      await f.close(tester);
    },
  );

  testWidgets(
    'screen session replacement saves the old paid answer without showing it in another profile',
    (tester) async {
      final original = _Fixture(), replacement = _Fixture();
      await original.open(tester);
      await original.send(tester, 'Original profile question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await original.send(tester, 'Original unsent detail.');
      await replacement.open(tester);
      original.answer(0, 'Only the original profile answer.');
      await tester.pump();
      await tester.pump();
      expect(
        original.chat.messages.any(
          (m) => m.text == 'Only the original profile answer.',
        ),
        isTrue,
      );
      expect(
        replacement.chat.messages.any(
          (m) => m.text == 'Only the original profile answer.',
        ),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(original.calls, hasLength(1));
      expect(replacement.calls, isEmpty);
      await replacement.close(tester);
      original.session.dispose();
      original.api.close();
    },
  );

  testWidgets(
    'profile clearing cancels the collector and rejects a late response',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'An old question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await f.send(tester, 'Another old detail.');
      await f.session.clear();
      f.answer(0, 'Must not reach a new profile.');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(f.calls, hasLength(1));
      expect(
        f.session.savedConversations.values
            .expand((chat) => chat.messages)
            .any((m) => m.text == 'Must not reach a new profile.'),
        isFalse,
      );
      await f.close(tester);
    },
  );

  testWidgets(
    'idle resets with messages and typing; one immutable batch preserves separate bubbles',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'I want to change jobs.');
      await tester.pump(const Duration(seconds: 5));
      expect(f.calls, isEmpty);
      await f.send(tester, 'I need more family time.');
      await tester.pump(const Duration(seconds: 5));
      expect(f.calls, isEmpty);
      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'Still typing',
      );
      await tester.pump(const Duration(seconds: 5));
      expect(f.calls, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(f.calls, hasLength(1));
      expect(f.calls.single['userMessageBatch'], [
        'I want to change jobs.',
        'I need more family time.',
      ]);
      expect(
        f.calls.single['question'],
        'I want to change jobs.\nI need more family time.',
      );
      expect(f.chat.messages.where((m) => m.fromUser), hasLength(2));
      expect(f.chat.turns.single.ack, 'sent');
      f.answer(0);
      await tester.pump();
      await tester.pump();
      expect(find.text('First thought.'), findsOneWidget);
      expect(find.text('Second thought.'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Second thought.'), findsOneWidget);
      expect(f.chat.turns.single.state, 'complete');
      await f.close(tester);
    },
  );

  testWidgets(
    'sentence-rich legacy reply finishes in five groups before the next queued turn',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'Explain my career outlook.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await f.send(tester, 'Then explain my practical next step.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      final paragraphs = List.generate(
        7,
        (index) =>
            'Thought $index. Keep its explanation together. Keep its next step together.',
      );
      final answer = paragraphs.join('\n\n');
      f.answer(0, answer);
      await tester.pump();
      await tester.pump();
      expect(find.text(paragraphs.first), findsOneWidget);
      expect(f.calls, hasLength(1));
      for (var gap = 0; gap < 4; gap++) {
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
        expect(f.calls, hasLength(gap == 3 ? 2 : 1));
      }
      expect(f.chat.messages.where((m) => m.text == answer), hasLength(1));
      final context = f.calls.last['conversationHistory'] as List;
      expect(
        context.any(
          (turn) => turn['role'] == 'assistant' && turn['content'] == answer,
        ),
        isTrue,
      );
      f.answer(1, 'Ready.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'sending remains available during processing and presentation; queued context includes prior answer',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'Career change question.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(f.calls, hasLength(1));
      await f.send(tester, 'Also explain the practical step.');
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('sendMessage')))
            .onPressed,
        isNotNull,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(f.chat.turns.first.ack, 'received');
      f.state = 'processing';
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(f.chat.turns.first.ack, 'processing');
      f.answer(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        f.calls,
        hasLength(1),
        reason: 'Next turn waits until the previous reply is presented',
      );
      await f.send(tester, 'One more detail.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(f.calls, hasLength(2));
      expect(f.calls.last['userMessageBatch'], [
        'Also explain the practical step.',
        'One more detail.',
      ]);
      final context = f.calls.last['conversationHistory'] as List;
      expect(
        context.any(
          (t) =>
              t['role'] == 'assistant' &&
              t['content'] == 'First thought.\n\nSecond thought.',
        ),
        isTrue,
      );
      expect(
        context.any((t) => t['content'] == 'Also explain the practical step.'),
        isFalse,
      );
      f.answer(1, 'Ready.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'four-message limit splits bursts without dropping text or duplicating a request',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      for (var i = 0; i < 5; i++) {
        await f.send(tester, 'Detail $i');
      }
      expect(f.chat.turns.map((t) => t.userMessages.length), [4, 1]);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(f.calls.single['userMessageBatch'], hasLength(4));
      f.answer(0, 'Ready.');
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(f.calls, hasLength(2));
      expect(f.calls.last['userMessageBatch'], ['Detail 4']);
      expect(f.calls.first['requestId'], isNot(f.calls.last['requestId']));
      f.answer(1, 'Done.');
      await tester.pump();
      await tester.pump();
      await f.close(tester);
    },
  );

  testWidgets(
    'uncertain request blocks automatic paid retries; Retry keeps original IDs and frozen batch',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'First detail.');
      await f.send(tester, 'Second detail.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      final original = f.calls.single;
      f.replies[0].complete(http.Response('{}', 503));
      await tester.pump();
      await tester.pump();
      expect(f.chat.turns.single.state, 'uncertain');
      await f.send(tester, 'A later question.');
      await tester.pump(const Duration(seconds: 10));
      expect(f.calls, hasLength(1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ValueKey('retry-turn-${f.chat.turns.first.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('retry-turn-${f.chat.turns.first.id}')),
      );
      await tester.pump();
      expect(f.calls, hasLength(2));
      expect(f.calls.last['requestId'], original['requestId']);
      expect(f.calls.last['userMessageBatch'], original['userMessageBatch']);
      expect(
        f.calls.last['conversationHistory'],
        original['conversationHistory'],
      );
      expect(f.chat.messages.where((m) => m.fromUser), hasLength(3));
      f.answer(1, 'Recovered.');
      await tester.pump();
      await tester.pump();
      await tester.pump();
      if (f.replies.length > 2) {
        f.answer(2, 'Next answer.');
        await tester.pump();
        await tester.pump();
      }
      await f.close(tester);
    },
  );

  testWidgets(
    'End chat cancels unsent messages while preserving an already requested answer',
    (tester) async {
      final f = _Fixture();
      await f.open(tester);
      await f.send(tester, 'Already requested.');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await f.send(tester, 'Do not send this later.');
      await tester.tap(find.byKey(const Key('end-chat')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'End chat'));
      await tester.pump();
      await tester.pump();
      expect(f.chat.ended, isTrue);
      expect(f.chat.turns.last.state, 'cancelled');
      f.answer(0, 'Saved answer.');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(f.calls, hasLength(1));
      expect(f.chat.messages.any((m) => m.text == 'Saved answer.'), isTrue);
      await f.close(tester);
    },
  );

  test('restart preserves uncertain batch and request ID without resending or confusing profile state', () async {
    final f = _Fixture();
    await f.session.calculate(
      dateTime: '2000-01-01T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: true,
    );
    final turn =
        ChatTurn(
            id: 'a' * 32,
            language: 'english',
            state: 'sending',
            ack: 'received',
          )
          ..messageIds.add('b' * 32)
          ..userMessages.add('A saved detail.');
    f.chat.turns.add(turn);
    f.chat.messages.add(
      ChatMessage(fromUser: true, text: 'A saved detail.', clientId: 'b' * 32),
    );
    f.chat.pending = true;
    f.chat.changed();
    await f.session.flushStorage();
    final restored = ProfileSession(api: f.api, vault: f.vault);
    await restored.restore();
    final restoredTurn = restored
        .conversation(guides.first.conversationKey)
        .turns
        .single;
    expect(restoredTurn.state, 'uncertain');
    expect(restoredTurn.ack, 'received');
    expect(restoredTurn.id, turn.id);
    expect(f.calls, isEmpty);
    await restored.clear();
    expect(restored.savedConversations, isEmpty);
    restored.dispose();
    f.session.dispose();
    f.api.close();
  });
}
