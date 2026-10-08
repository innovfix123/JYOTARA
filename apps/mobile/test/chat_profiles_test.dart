import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/main.dart';
import 'package:jyotara/chat_profile_picker.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/profile_gender.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'failed question returns to composer after storage restore without sending',
    (tester) async {
      String? disk;
      var questionCalls = 0;
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      ProfileSession make() => ProfileSession(
        vault: vault,
        api: JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('kundli')) {
              return chartReply('retry-profile');
            }
            questionCalls++;
            return http.Response('{}', 503);
          }),
        ),
      );
      final first = make();
      await first.calculate(
        dateTime: '2002-07-29T05:00:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      first.conversation(guides.first.name).messages.addAll(const [
        ChatMessage(fromUser: true, text: 'திருமணத்திற்கு ஏற்ற காலம் எப்போது?'),
        ChatMessage(
          fromUser: false,
          text: 'Unable to connect.',
          label: 'ANSWER NOT CONFIRMED',
        ),
      ]);
      first.conversation(guides.first.name).changed();
      await first.flushStorage();
      final restored = make();
      await restored.restore();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(guide: guides.first, session: restored),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chatInput')))
            .controller!
            .text,
        'திருமணத்திற்கு ஏற்ற காலம் எப்போது?',
      );
      expect(
        questionCalls,
        0,
        reason: 'Restoring a draft must not make a paid request',
      );
    },
  );
  testWidgets(
    'selection uses the chosen chart and its history; End blocks sending and Continue restores it',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      Future<ProfileSession> make(String id) async {
        final session = ProfileSession(
          api: JyotaraApiClient(
            baseUrl: 'https://example.test',
            client: MockClient((r) async {
              if (r.url.path.endsWith('kundli')) return chartReply(id);
              final body = jsonDecode(r.body);
              if (body['question'] ==
                  'Show the selected profile rasi, nakshatra and current Saturn status.') {
                expect(body['chartTicket'], 'ticket-Profile B');
                return http.Response(
                  jsonEncode({
                    'profileId': id,
                    'answer': 'Selected Profile B chart overview',
                    'answerMode': 'chart_guidance',
                    'evidence': [],
                  }),
                  200,
                );
              }
              requests.add(body);
              return http.Response(
                jsonEncode({
                  'profileId': id,
                  'answer': 'Fixture answer',
                  'evidence': [],
                }),
                200,
              );
            }),
          ),
        );
        await session.calculate(
          dateTime: '1995-01-10T08:30:00+05:30',
          latitude: 11,
          longitude: 77,
          exactTime: true,
          nickname: id,
          gender: ProfileGender.male,
          birthplaceLabel: 'Erode',
        );
        return session;
      }

      final a = await make('Profile A'), b = await make('Profile B');
      a
          .conversation('Meera')
          .messages
          .add(const ChatMessage(fromUser: true, text: 'Private A question'));
      await tester.pumpWidget(
        MaterialApp(
          home: ChatProfilePicker(
            guide: guides.first,
            loadProfiles: () async => [
              SavedKundli('a', a),
              SavedKundli('b', b),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('chat-profile-b')));
      await tester.tap(find.byKey(const ValueKey('chat-profile-b')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Full name: Profile B'), findsNothing);
      expect(find.text('Private A question'), findsNothing);
      expect(find.textContaining('Welcome!'), findsOneWidget);
      expect(find.textContaining('I’m Meera.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chatInput')), 'hello');
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pumpAndSettle();
      expect(
        requests,
        isEmpty,
        reason: 'A greeting must not spend a paid reading or question quota',
      );
      expect(b.conversation('Meera').pending, isFalse);
      expect(b.conversation('Meera').messages.last.text, contains('Hi!'));

      await tester.enterText(
        find.byKey(const Key('chatInput')),
        'How can I communicate better?',
      );
      await tester.tap(find.byKey(const Key('sendMessage')));
      await tester.pumpAndSettle();
      expect(requests.single['chartTicket'], 'ticket-Profile B');
      expect(requests.single['guide'], 'Meera');
      expect(a.conversation('Meera').messages.length, 1);
      expect(
        find.byType(ActionChip),
        findsNothing,
        reason:
            'Suggestions hide after conversation starts to leave room for chat',
      );
      expect(requests, hasLength(1));

      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End chat'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('End chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chatInput')), findsNothing);
      expect(b.conversation('Meera').ended, true);
      await tester.tap(find.text('Continue this chat'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chatInput')), findsOneWidget);
      expect(b.conversation('Meera').ended, false);
    },
  );
  test(
    'ended state and private rating survive restart alongside messages',
    () async {
      String? disk;
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (v) async => disk = v,
      );
      JyotaraApiClient api() => JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => chartReply('saved')),
      );
      final s = ProfileSession(api: api(), vault: vault);
      await s.calculate(
        dateTime: '1995-01-10T08:30:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      final chat = s.conversation('Meera');
      chat.messages.add(
        const ChatMessage(fromUser: true, text: 'Saved question'),
      );
      chat.ended = true;
      chat.rating = 4;
      chat.changed();
      await s.flushStorage();
      final restored = ProfileSession(api: api(), vault: vault);
      await restored.restore();
      expect(restored.conversation('Meera').ended, true);
      expect(restored.conversation('Meera').rating, 4);
      expect(
        restored.conversation('Meera').messages.single.text,
        'Saved question',
      );
      expect(restored.conversation('Arivan').ended, false);
    },
  );
}
